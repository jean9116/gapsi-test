locals {
  shared = google_project.this["shared"].project_id

  # Permisos del Terraform de cada ambiente: administración por servicio, sin owner ni editor.
  tf_apply_roles = [
    "roles/cloudscheduler.admin",
    "roles/cloudsql.admin",
    "roles/compute.loadBalancerAdmin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/logging.configWriter",
    "roles/monitoring.admin",
    "roles/pubsub.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/servicenetworking.networksAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
  ]

  # El plan de las PR solo lee: código no revisado nunca tiene permisos de escritura.
  tf_plan_roles = [
    "roles/viewer",
    "roles/iam.securityReviewer",
    "roles/secretmanager.viewer",
  ]

  tf_apply_bindings = merge([
    for e in local.envs : { for r in local.tf_apply_roles : "${e}|${r}" => { env = e, role = r } }
  ]...)

  tf_plan_bindings = merge([
    for e in local.envs : { for r in local.tf_plan_roles : "${e}|${r}" => { env = e, role = r } }
  ]...)
}

# ---------- Service accounts de CI/CD (proyecto shared) ----------
resource "google_service_account" "tf_apply" {
  for_each = toset(local.envs)

  project      = local.shared
  account_id   = "sa-tf-${each.key}"
  display_name = "Terraform apply ${each.key}"
  description  = "Aplica el stack platform solo en ${each.key}."
}

resource "google_service_account" "tf_plan" {
  project      = local.shared
  account_id   = "sa-tf-plan"
  display_name = "Terraform plan (PR)"
  description  = "Plan de solo lectura en las pull requests."
}

resource "google_service_account" "cicd_app" {
  project      = local.shared
  account_id   = "sa-cicd-app"
  display_name = "CI/CD de aplicaciones"
  description  = "Construye imágenes y despliega revisiones de Cloud Run."
}

resource "google_project_iam_member" "tf_apply" {
  for_each = local.tf_apply_bindings

  project = google_project.this[each.value.env].project_id
  role    = each.value.role
  member  = google_service_account.tf_apply[each.value.env].member
}

resource "google_project_iam_member" "tf_plan" {
  for_each = local.tf_plan_bindings

  project = google_project.this[each.value.env].project_id
  role    = each.value.role
  member  = google_service_account.tf_plan.member
}

# Logs de Cloud Build en Cloud Logging (sin bucket de logs por defecto).
resource "google_project_iam_member" "ci_logs" {
  for_each = {
    tf-plan  = google_service_account.tf_plan.member
    cicd-app = google_service_account.cicd_app.member
    tf-dev   = google_service_account.tf_apply["dev"].member
    tf-qa    = google_service_account.tf_apply["qa"].member
    tf-prod  = google_service_account.tf_apply["prod"].member
  }

  project = local.shared
  role    = "roles/logging.logWriter"
  member  = each.value
}

resource "google_artifact_registry_repository_iam_member" "cicd_app_writer" {
  project    = google_artifact_registry_repository.docker.project
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.cicd_app.member
}

# Cada SA de Terraform solo lee/escribe su prefijo del estado (más el listado del bucket).
resource "google_storage_bucket_iam_member" "tf_apply_state" {
  for_each = toset(local.envs)

  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectUser"
  member = google_service_account.tf_apply[each.key].member

  condition {
    title      = "solo-platform-${each.key}"
    expression = "resource.type == \"storage.googleapis.com/Bucket\" || resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.tfstate.name}/objects/platform/${each.key}/\")"
  }
}

resource "google_storage_bucket_iam_member" "tf_plan_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectUser"
  member = google_service_account.tf_plan.member

  condition {
    title      = "solo-platform"
    expression = "resource.type == \"storage.googleapis.com/Bucket\" || resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.tfstate.name}/objects/platform/\")"
  }
}

# ---------- Triggers de Cloud Build (requieren el repositorio conectado) ----------
locals {
  triggers_enabled = var.github_repository != null
}

resource "google_cloudbuild_trigger" "tf_plan" {
  count = local.triggers_enabled ? 1 : 0

  project         = local.shared
  location        = var.region
  name            = "${var.app_name}-tf-plan"
  description     = "PR: fmt, validate, tflint, checkov, tests y plan de los 3 ambientes."
  service_account = google_service_account.tf_plan.id
  filename        = "cicd/cloudbuild-terraform-plan.yaml"
  included_files  = ["terraform/**", "cicd/cloudbuild-terraform-plan.yaml"]

  repository_event_config {
    repository = var.github_repository
    pull_request {
      branch          = "^${var.main_branch}$"
      comment_control = "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"
    }
  }

  substitutions = {
    _STATE_BUCKET = google_storage_bucket.tfstate.name
  }
}

# Apply por ambiente al hacer merge. QA y PROD necesitan aprobación manual en Cloud Build.
resource "google_cloudbuild_trigger" "tf_apply" {
  for_each = local.triggers_enabled ? toset(local.envs) : toset([])

  project         = local.shared
  location        = var.region
  name            = "${var.app_name}-tf-apply-${each.key}"
  description     = "Merge a ${var.main_branch}: terraform apply en ${each.key}."
  service_account = google_service_account.tf_apply[each.key].id
  filename        = "cicd/cloudbuild-terraform-apply.yaml"
  included_files  = ["terraform/**", "cicd/cloudbuild-terraform-apply.yaml"]

  repository_event_config {
    repository = var.github_repository
    push {
      branch = "^${var.main_branch}$"
    }
  }

  approval_config {
    approval_required = each.key != "dev"
  }

  substitutions = {
    _ENV          = each.key
    _STATE_BUCKET = google_storage_bucket.tfstate.name
  }
}

# Aplicaciones: build una vez y despliegue automático en dev.
resource "google_cloudbuild_trigger" "app_build" {
  count = local.triggers_enabled ? 1 : 0

  project         = local.shared
  location        = var.region
  name            = "${var.app_name}-app-build"
  description     = "Merge a ${var.main_branch}: build, escaneo, push y despliegue en dev."
  service_account = google_service_account.cicd_app.id
  filename        = "cicd/cloudbuild-app.yaml"
  included_files  = ["app/**", "cicd/cloudbuild-app.yaml"]

  repository_event_config {
    repository = var.github_repository
    push {
      branch = "^${var.main_branch}$"
    }
  }

  substitutions = {
    _REGISTRY = "${var.region}-docker.pkg.dev/${local.shared}/${google_artifact_registry_repository.docker.repository_id}"
    _PROJECT  = google_project.this["dev"].project_id
    _ENV      = "dev"
  }
}

# Promoción de la misma imagen (por tag = SHA) a qa y prod. Se lanza a mano; prod con aprobación.
resource "google_cloudbuild_trigger" "app_promote" {
  for_each = local.triggers_enabled ? toset(["qa", "prod"]) : toset([])

  project         = local.shared
  location        = var.region
  name            = "${var.app_name}-app-promote-${each.key}"
  description     = "Promueve una versión ya probada a ${each.key} (_TAG = SHA corto)."
  service_account = google_service_account.cicd_app.id

  source_to_build {
    repository = var.github_repository
    ref        = "refs/heads/${var.main_branch}"
    repo_type  = "GITHUB"
  }

  git_file_source {
    path       = "cicd/cloudbuild-promote.yaml"
    repository = var.github_repository
    revision   = "refs/heads/${var.main_branch}"
    repo_type  = "GITHUB"
  }

  approval_config {
    approval_required = each.key == "prod"
  }

  substitutions = {
    _REGISTRY = "${var.region}-docker.pkg.dev/${local.shared}/${google_artifact_registry_repository.docker.repository_id}"
    _PROJECT  = google_project.this[each.key].project_id
    _ENV      = each.key
    _TAG      = ""
  }
}
