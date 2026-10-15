output "url" {
  description = "URL pública de la plataforma."
  value       = local.public_url
}

output "lb_ip" {
  description = "IP del balanceador (apuntar aquí el DNS si se usa dominio propio)."
  value       = module.edge.ip_address
}

output "services" {
  description = "Servicios Cloud Run."
  value = {
    frontend = module.frontend.name
    api      = module.api.name
    worker   = module.worker.name
  }
}

output "jobs" {
  description = "Cloud Run Jobs."
  value       = concat([for j in module.jobs : j.name], [module.migrate.name])
}

output "sql_connection_name" {
  description = "Connection name de Cloud SQL."
  value       = module.database.connection_name
}

output "sql_instance" {
  description = "Instancia de Cloud SQL."
  value       = module.database.instance_name
}

output "db_admin_secret" {
  description = "Secreto con la contraseña de app_admin."
  value       = module.database.admin_password_secret_id
}

output "files_bucket" {
  description = "Bucket de archivos."
  value       = module.files.name
}

output "topics" {
  description = "Topics de Pub/Sub."
  value       = module.pubsub.topic_names
}

output "service_accounts" {
  description = "Service accounts de runtime."
  value       = module.iam.emails
}

output "external_app_service_accounts" {
  description = "SAs de las integraciones externas."
  value       = module.pubsub.external_service_accounts
}
