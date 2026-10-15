# Una service account por carga de trabajo. Los roles de proyecto se limitan a telemetría y
# conexión a Cloud SQL; los permisos sobre datos (bucket, topics, secretos) se conceden en cada
# recurso, no en el proyecto.
resource "google_service_account" "this" {
  for_each = var.service_accounts

  project      = var.project_id
  account_id   = "sa-${each.key}"
  display_name = "sa-${each.key}"
  description  = each.value.description
}

locals {
  bindings = merge([
    for sa, cfg in var.service_accounts : {
      for role in cfg.project_roles : "${sa}|${role}" => { sa = sa, role = role }
    }
  ]...)
}

resource "google_project_iam_member" "this" {
  for_each = local.bindings

  project = var.project_id
  role    = each.value.role
  member  = google_service_account.this[each.value.sa].member
}
