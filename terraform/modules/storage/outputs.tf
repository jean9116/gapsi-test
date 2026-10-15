output "name" {
  description = "Nombre del bucket."
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "URL gs:// del bucket."
  value       = google_storage_bucket.this.url
}
