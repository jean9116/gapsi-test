output "instance_name" {
  description = "Nombre de la instancia Cloud SQL."
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Connection name (proyecto:región:instancia) para el conector de Cloud SQL."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip" {
  description = "IP privada de la instancia."
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  description = "Base de datos de la aplicación."
  value       = google_sql_database.app.name
}

output "iam_users" {
  description = "Usuarios IAM de PostgreSQL por service account."
  value       = { for k, u in google_sql_user.iam : k => u.name }
}

output "admin_password_secret_id" {
  description = "Secreto con la contraseña del administrador."
  value       = google_secret_manager_secret.admin_password.secret_id
}
