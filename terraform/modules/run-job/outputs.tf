output "name" {
  description = "Nombre del job."
  value       = google_cloud_run_v2_job.this.name
}

output "id" {
  description = "ID del job."
  value       = google_cloud_run_v2_job.this.id
}
