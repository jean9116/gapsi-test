output "ip_address" {
  description = "IP pública del balanceador."
  value       = google_compute_global_address.this.address
}

output "domain" {
  description = "Dominio servido (propio o sslip.io)."
  value       = local.domain
}

output "url" {
  description = "URL pública."
  value       = "https://${local.domain}"
}

output "security_policy" {
  description = "Política de Cloud Armor."
  value       = google_compute_security_policy.this.name
}

output "url_map" {
  description = "URL map principal (para métricas del LB)."
  value       = google_compute_url_map.https.name
}
