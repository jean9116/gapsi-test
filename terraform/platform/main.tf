# ======================= Identidades =======================
module "iam" {
  source = "../modules/iam"

  project_id       = var.project_id
  service_accounts = local.service_accounts

  depends_on = [google_project_service.this]
}

# La API firma URLs de subida/descarga de GCS con su propia SA (signBlob), sin claves.
resource "google_service_account_iam_member" "api_sign_urls" {
  service_account_id = module.iam.ids["api"]
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = module.iam.members["api"]
}

# ======================= Red =======================
module "network" {
  source = "../modules/network"

  project_id         = var.project_id
  region             = var.region
  name               = local.name
  app_subnet_cidr    = var.app_subnet_cidr
  flow_logs_sampling = var.flow_logs_sampling

  depends_on = [google_project_service.this]
}

# ======================= Base de datos =======================
module "database" {
  source = "../modules/database"

  project_id               = var.project_id
  region                   = var.region
  name                     = local.name
  network_id               = module.network.network_id
  psa_connection           = module.network.psa_connection
  tier                     = var.db.tier
  availability_type        = var.db.availability_type
  disk_size_gb             = var.db.disk_size_gb
  disk_autoresize_limit_gb = var.db.disk_autoresize_limit_gb
  backup_retained_count    = var.db.backup_retained_count
  pitr_days                = var.db.pitr_days
  backup_location          = var.db.backup_location
  max_connections          = var.db.max_connections
  deletion_protection      = var.deletion_protection
  iam_service_accounts     = { for k in local.db_iam_sas : k => module.iam.emails[k] }
  labels                   = local.labels
}

resource "google_secret_manager_secret_iam_member" "migrate_db_admin" {
  project   = var.project_id
  secret_id = module.database.admin_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = module.iam.members["migrate"]
}

# ======================= Secretos de aplicación =======================
ephemeral "random_password" "app" {
  for_each = { for k, v in var.app_secrets : k => v if v.generate }

  length  = 48
  special = false
}

resource "google_secret_manager_secret" "app" {
  for_each = var.app_secrets

  project   = var.project_id
  secret_id = "${local.name}-${each.key}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}

resource "google_secret_manager_secret_version" "generated" {
  for_each = { for k, v in var.app_secrets : k => v if v.generate }

  secret                 = google_secret_manager_secret.app[each.key].id
  secret_data_wo         = ephemeral.random_password.app[each.key].result
  secret_data_wo_version = 1
}

resource "google_secret_manager_secret_iam_member" "app" {
  for_each = merge([
    for s, cfg in var.app_secrets : { for a in cfg.accessors : "${s}|${a}" => { secret = s, sa = a } }
  ]...)

  project   = var.project_id
  secret_id = google_secret_manager_secret.app[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = module.iam.members[each.value.sa]
}

locals {
  # Solo se inyectan como variables de entorno los secretos que tienen versión desde el primer apply.
  secret_env = {
    for sa in ["api", "worker", "batch"] : sa => {
      for s, cfg in var.app_secrets :
      coalesce(cfg.env_name, upper(replace(s, "-", "_"))) => google_secret_manager_secret.app[s].secret_id
      if cfg.generate && contains(cfg.accessors, sa)
    }
  }
}

# ======================= Almacenamiento de archivos =======================
module "files" {
  source = "../modules/storage"

  project_id    = var.project_id
  region        = var.region
  name          = "${var.project_id}-files"
  cors_origins  = [local.public_url]
  force_destroy = var.files_force_destroy
  labels        = local.labels
  object_admins = { for k in ["api", "worker", "batch"] : k => module.iam.members[k] }

  depends_on = [google_project_service.this]
}

# ======================= Cómputo: servicios =======================
locals {
  app_env = {
    APP_ENV                = var.environment
    NODE_ENV               = "production"
    GOOGLE_CLOUD_PROJECT   = var.project_id
    DB_INSTANCE_CONNECTION = module.database.connection_name
    DB_NAME                = module.database.database_name
    DB_IP_TYPE             = "PRIVATE"
    FILES_BUCKET           = module.files.name
    PUBLIC_URL             = local.public_url
  }
  topic_env = { for k, t in module.pubsub.topic_names : "TOPIC_${upper(replace(k, "-", "_"))}" => t }
}

module "frontend" {
  source = "../modules/run-service"

  project_id            = var.project_id
  region                = var.region
  name                  = "${local.name}-frontend"
  image                 = local.image.frontend
  service_account_email = module.iam.emails["frontend"]
  ingress               = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  public_via_lb         = true
  cpu                   = var.services.frontend.cpu
  memory                = var.services.frontend.memory
  min_instances         = var.services.frontend.min_instances
  max_instances         = var.services.frontend.max_instances
  concurrency           = var.services.frontend.concurrency
  deletion_protection   = var.deletion_protection
  env                   = { APP_ENV = var.environment }
  labels                = local.labels
}

module "api" {
  source = "../modules/run-service"

  project_id            = var.project_id
  region                = var.region
  name                  = "${local.name}-api"
  image                 = local.image.api
  service_account_email = module.iam.emails["api"]
  ingress               = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  public_via_lb         = true
  cpu                   = var.services.api.cpu
  memory                = var.services.api.memory
  min_instances         = var.services.api.min_instances
  max_instances         = var.services.api.max_instances
  concurrency           = var.services.api.concurrency
  cpu_always_allocated  = var.services.api.cpu_always_allocated
  vpc_network           = module.network.network_name
  vpc_subnetwork        = module.network.app_subnet_name
  deletion_protection   = var.deletion_protection
  env                   = merge(local.app_env, local.topic_env, { DB_USER = module.database.iam_users["api"] })
  secret_env            = local.secret_env["api"]
  labels                = local.labels

  depends_on = [google_secret_manager_secret_iam_member.app, google_secret_manager_secret_version.generated]
}

# El worker no es público: solo lo invoca Pub/Sub (push con OIDC) desde dentro de GCP.
module "worker" {
  source = "../modules/run-service"

  project_id            = var.project_id
  region                = var.region
  name                  = "${local.name}-worker"
  image                 = local.image.worker
  service_account_email = module.iam.emails["worker"]
  ingress               = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invokers              = { pubsub = module.iam.members["pubsub-push"] }
  cpu                   = var.services.worker.cpu
  memory                = var.services.worker.memory
  min_instances         = var.services.worker.min_instances
  max_instances         = var.services.worker.max_instances
  concurrency           = var.services.worker.concurrency
  timeout_seconds       = 300
  vpc_network           = module.network.network_name
  vpc_subnetwork        = module.network.app_subnet_name
  deletion_protection   = var.deletion_protection
  env                   = merge(local.app_env, local.topic_env, { DB_USER = module.database.iam_users["worker"] })
  secret_env            = local.secret_env["worker"]
  labels                = local.labels

  depends_on = [google_secret_manager_secret_iam_member.app, google_secret_manager_secret_version.generated]
}

# ======================= Mensajería asíncrona =======================
module "pubsub" {
  source = "../modules/pubsub"

  project_id         = var.project_id
  name               = local.name
  topics             = var.topics
  worker_url         = module.worker.uri
  push_invoker_email = module.iam.emails["pubsub-push"]
  external_apps      = var.external_apps
  publishers         = { for k in ["api", "worker", "batch"] : k => module.iam.members[k] }
  labels             = local.labels

  depends_on = [google_project_service.this]
}

# ======================= Batch =======================
module "jobs" {
  source   = "../modules/run-job"
  for_each = var.jobs

  project_id                      = var.project_id
  region                          = var.region
  name                            = "${local.name}-${each.key}"
  image                           = local.image.batch
  args                            = each.value.args
  service_account_email           = module.iam.emails["batch"]
  scheduler_service_account_email = module.iam.emails["scheduler"]
  schedule                        = each.value.schedule
  cpu                             = each.value.cpu
  memory                          = each.value.memory
  task_count                      = each.value.task_count
  parallelism                     = each.value.parallelism
  max_retries                     = each.value.max_retries
  timeout_seconds                 = each.value.timeout_s
  vpc_network                     = module.network.network_name
  vpc_subnetwork                  = module.network.app_subnet_name
  deletion_protection             = var.deletion_protection
  env                             = merge(local.app_env, local.topic_env, { DB_USER = module.database.iam_users["batch"] })
  secret_env                      = local.secret_env["batch"]
  labels                          = local.labels

  depends_on = [google_secret_manager_secret_iam_member.app, google_secret_manager_secret_version.generated]
}

# Migraciones de esquema: job sin programación que el pipeline ejecuta antes de desplegar la API.
module "migrate" {
  source = "../modules/run-job"

  project_id                      = var.project_id
  region                          = var.region
  name                            = "${local.name}-migrate"
  image                           = local.image.api
  args                            = ["npm", "run", "migrate"]
  service_account_email           = module.iam.emails["migrate"]
  scheduler_service_account_email = module.iam.emails["scheduler"]
  max_retries                     = 0
  timeout_seconds                 = 900
  vpc_network                     = module.network.network_name
  vpc_subnetwork                  = module.network.app_subnet_name
  deletion_protection             = var.deletion_protection
  env                             = merge(local.app_env, { DB_USER = "app_admin" })
  secret_env                      = { DB_PASSWORD = module.database.admin_password_secret_id }
  labels                          = local.labels

  depends_on = [google_secret_manager_secret_iam_member.migrate_db_admin]
}

# ======================= Borde: LB + CDN + Cloud Armor =======================
module "edge" {
  source = "../modules/edge"

  project_id            = var.project_id
  region                = var.region
  name                  = local.name
  frontend_service_name = module.frontend.name
  api_service_name      = module.api.name
  domain                = var.domain
  enable_cdn            = var.enable_cdn
  enable_waf            = var.enable_waf
  rate_limit_per_minute = var.rate_limit_per_minute

  depends_on = [google_project_service.this]
}

# ======================= Observabilidad =======================
module "observability" {
  source = "../modules/observability"

  project_id          = var.project_id
  name                = local.name
  notification_emails = var.notification_emails
  log_retention_days  = var.log_retention_days
  latency_p95_ms      = var.latency_p95_ms
  run_services        = [module.frontend.name, module.api.name, module.worker.name]
  run_jobs            = concat([for j in module.jobs : j.name], [module.migrate.name])
  sql_database_id     = "${var.project_id}:${module.database.instance_name}"
  dlq_subscriptions   = values(module.pubsub.dlq_subscription_names)
  work_subscriptions  = [for k, v in var.topics : "${local.name}-${k}-worker" if v.push_path != null]
  uptime_host         = module.edge.domain

  depends_on = [google_project_service.this]
}

# ======================= Despliegue desde CI/CD =======================
# El pipeline (SA en el proyecto shared) puede publicar revisiones y ejecutar jobs,
# y actuar como las SAs de runtime, pero no puede tocar IAM, red ni BD.
resource "google_project_iam_member" "deployer_run" {
  count = var.deployer_service_account == null ? 0 : 1

  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${var.deployer_service_account}"
}

resource "google_service_account_iam_member" "deployer_act_as" {
  for_each = var.deployer_service_account == null ? toset([]) : toset(["frontend", "api", "worker", "batch", "migrate"])

  service_account_id = module.iam.ids[each.key]
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.deployer_service_account}"
}
