output "network_id" {
  description = "ID de la VPC."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Nombre de la VPC."
  value       = google_compute_network.this.name
}

output "app_subnet_id" {
  description = "ID de la subred privada de aplicaciones."
  value       = google_compute_subnetwork.app.id
}

output "app_subnet_name" {
  description = "Nombre de la subred privada de aplicaciones."
  value       = google_compute_subnetwork.app.name
}

output "psa_connection" {
  description = "Conexión de Private Service Access (dependencia de Cloud SQL)."
  value       = google_service_networking_connection.psa.id
}
