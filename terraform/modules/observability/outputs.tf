output "notification_channels" {
  description = "Canales de notificación."
  value       = local.channels
}

output "dashboard_id" {
  description = "ID del dashboard."
  value       = google_monitoring_dashboard.this.id
}
