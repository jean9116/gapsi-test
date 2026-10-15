locals {
  name = "${var.app_name}-${var.environment}"

  labels = {
    app         = var.app_name
    env         = var.environment
    owner       = var.owner
    managed-by  = "terraform"
    cost-center = "${var.app_name}-${var.environment}"
  }

  telemetry_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent",
  ]
  db_roles = [
    "roles/cloudsql.client",
    "roles/cloudsql.instanceUser",
  ]

  # Una SA por carga de trabajo. Nada de roles amplios (editor/owner) ni de la SA por defecto.
  service_accounts = {
    frontend    = { description = "Runtime del frontend (solo telemetría)", project_roles = local.telemetry_roles }
    api         = { description = "Runtime de la API", project_roles = concat(local.telemetry_roles, local.db_roles) }
    worker      = { description = "Runtime del worker de eventos", project_roles = concat(local.telemetry_roles, local.db_roles) }
    batch       = { description = "Runtime de los procesos batch", project_roles = concat(local.telemetry_roles, local.db_roles) }
    migrate     = { description = "Migraciones de esquema (usa el usuario admin)", project_roles = concat(local.telemetry_roles, ["roles/cloudsql.client"]) }
    scheduler   = { description = "Cloud Scheduler: solo lanza los jobs batch", project_roles = [] }
    pubsub-push = { description = "Firma el token OIDC del push de Pub/Sub al worker", project_roles = [] }
  }

  db_iam_sas = ["api", "worker", "batch"]

  image = {
    for k in ["frontend", "api", "worker", "batch"] :
    k => lookup(var.images, k, k == "batch" ? "us-docker.pkg.dev/cloudrun/container/job" : "us-docker.pkg.dev/cloudrun/container/hello")
  }

  public_url = "https://${module.edge.domain}"
}
