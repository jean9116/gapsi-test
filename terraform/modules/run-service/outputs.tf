output "name" {
  description = "Nombre del servicio."
  value       = google_cloud_run_v2_service.this.name
}

output "uri" {
  description = "URL *.run.app del servicio (con ingress restringido solo responde desde el LB o la VPC)."
  value       = google_cloud_run_v2_service.this.uri
}

output "id" {
  description = "ID del servicio."
  value       = google_cloud_run_v2_service.this.id
}
