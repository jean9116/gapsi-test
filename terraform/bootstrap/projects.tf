locals {
  envs = keys(var.environments)

  projects = merge(
    { shared = "${var.app_name}-shared-${var.suffix}" },
    { for e in local.envs : e => "${var.app_name}-${e}-${var.suffix}" }
  )
}

resource "google_project" "this" {
  for_each = local.projects

  project_id      = each.value
  name            = each.value
  org_id          = var.folder_id == null ? var.org_id : null
  folder_id       = var.folder_id
  billing_account = var.billing_account
  # Sin red "default" (reglas de firewall abiertas); cada stack crea su VPC.
  auto_create_network = false
  labels              = { app = var.app_name, env = each.key }

  # Shared y prod no se borran por accidente; dev y qa se pueden recrear.
  deletion_policy = contains(["shared", "prod"], each.key) ? "PREVENT" : "DELETE"
}

locals {
  shared_apis = [
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ]

  # Lo mínimo para que el stack platform pueda habilitar el resto y para que exista
  # el agente de Cloud Run (lectura de imágenes del proyecto shared).
  env_bootstrap_apis = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "serviceusage.googleapis.com",
  ]

  env_apis = merge([
    for e in local.envs : { for a in local.env_bootstrap_apis : "${e}|${a}" => { env = e, api = a } }
  ]...)
}

resource "google_project_service" "shared" {
  for_each = toset(local.shared_apis)

  project            = google_project.this["shared"].project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "env" {
  for_each = local.env_apis

  project            = google_project.this[each.value.env].project_id
  service            = each.value.api
  disable_on_destroy = false
}
