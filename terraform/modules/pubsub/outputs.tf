output "topic_ids" {
  description = "ID de cada topic."
  value       = { for k, t in google_pubsub_topic.this : k => t.id }
}

output "topic_names" {
  description = "Nombre de cada topic."
  value       = { for k, t in google_pubsub_topic.this : k => t.name }
}

output "dlq_subscription_names" {
  description = "Suscripciones de DLQ (para alertas)."
  value       = { for k, s in google_pubsub_subscription.dlq : k => s.name }
}

output "external_service_accounts" {
  description = "Service account de cada aplicación externa."
  value       = { for k, sa in google_service_account.external : k => sa.email }
}
