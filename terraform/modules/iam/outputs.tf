output "emails" {
  description = "Correo de cada service account."
  value       = { for k, sa in google_service_account.this : k => sa.email }
}

output "members" {
  description = "Miembro IAM (serviceAccount:...) de cada service account."
  value       = { for k, sa in google_service_account.this : k => sa.member }
}

output "ids" {
  description = "ID completo de cada service account."
  value       = { for k, sa in google_service_account.this : k => sa.id }
}
