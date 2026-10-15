data "google_project" "this" {
  project_id = var.project_id
}

locals {
  pubsub_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  external_publish = merge([
    for app, cfg in var.external_apps : {
      for t in cfg.publish_topics : "${app}|${t}" => { app = app, topic = t }
    }
  ]...)

  external_consume = merge([
    for app, cfg in var.external_apps : {
      for t in cfg.consume_topics : "${app}|${t}" => { app = app, topic = t }
    }
  ]...)

  publisher_bindings = merge([
    for k, m in var.publishers : {
      for t in keys(var.topics) : "${k}|${t}" => { member = m, topic = t }
    }
  ]...)
}

resource "google_pubsub_topic" "this" {
  for_each = var.topics

  project                    = var.project_id
  name                       = "${var.name}-${each.key}"
  message_retention_duration = var.message_retention
  labels                     = var.labels
}

resource "google_pubsub_topic" "dlq" {
  for_each = var.topics

  project                    = var.project_id
  name                       = "${var.name}-${each.key}-dlq"
  message_retention_duration = var.message_retention
  labels                     = var.labels
}

# Suscripción a la DLQ para inspeccionar y reprocesar mensajes fallidos.
resource "google_pubsub_subscription" "dlq" {
  for_each = var.topics

  project                    = var.project_id
  name                       = "${var.name}-${each.key}-dlq-sub"
  topic                      = google_pubsub_topic.dlq[each.key].id
  ack_deadline_seconds       = 60
  message_retention_duration = var.message_retention
  retain_acked_messages      = false
  labels                     = var.labels

  expiration_policy {
    ttl = ""
  }
}

# Push autenticado al worker: reintentos con backoff exponencial y DLQ tras N intentos.
resource "google_pubsub_subscription" "worker" {
  for_each = { for k, v in var.topics : k => v if v.push_path != null }

  project                    = var.project_id
  name                       = "${var.name}-${each.key}-worker"
  topic                      = google_pubsub_topic.this[each.key].id
  ack_deadline_seconds       = var.ack_deadline_seconds
  message_retention_duration = var.message_retention
  labels                     = var.labels

  push_config {
    push_endpoint = "${var.worker_url}${each.value.push_path}"
    oidc_token {
      service_account_email = var.push_invoker_email
      audience              = var.worker_url
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq[each.key].id
    max_delivery_attempts = var.max_delivery_attempts
  }

  expiration_policy {
    ttl = ""
  }
}

# El agente de Pub/Sub necesita publicar en la DLQ y consumir de la suscripción origen.
resource "google_pubsub_topic_iam_member" "dlq_publisher" {
  for_each = var.topics

  project = var.project_id
  topic   = google_pubsub_topic.dlq[each.key].name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_agent
}

resource "google_pubsub_subscription_iam_member" "worker_subscriber" {
  for_each = google_pubsub_subscription.worker

  project      = var.project_id
  subscription = each.value.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}

resource "google_pubsub_topic_iam_member" "publishers" {
  for_each = local.publisher_bindings

  project = var.project_id
  topic   = google_pubsub_topic.this[each.value.topic].name
  role    = "roles/pubsub.publisher"
  member  = each.value.member
}

# --- Integraciones externas: una SA por aplicación, permisos solo en sus topics ---
resource "google_service_account" "external" {
  for_each = var.external_apps

  project      = var.project_id
  account_id   = "${var.sa_prefix}-ext-${each.key}"
  display_name = "${var.sa_prefix}-ext-${each.key}"
  description  = "Integración externa ${each.key}: publica y consume solo en sus topics."
}

resource "google_pubsub_topic_iam_member" "external_publisher" {
  for_each = local.external_publish

  project = var.project_id
  topic   = google_pubsub_topic.this[each.value.topic].name
  role    = "roles/pubsub.publisher"
  member  = google_service_account.external[each.value.app].member
}

resource "google_pubsub_subscription" "external" {
  for_each = local.external_consume

  project                    = var.project_id
  name                       = "${var.name}-${each.value.topic}-${each.value.app}"
  topic                      = google_pubsub_topic.this[each.value.topic].id
  ack_deadline_seconds       = var.ack_deadline_seconds
  message_retention_duration = var.message_retention
  labels                     = var.labels

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq[each.value.topic].id
    max_delivery_attempts = var.max_delivery_attempts
  }

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_subscription_iam_member" "external_subscriber" {
  for_each = local.external_consume

  project      = var.project_id
  subscription = google_pubsub_subscription.external[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = google_service_account.external[each.value.app].member
}

resource "google_pubsub_subscription_iam_member" "external_dlq_agent" {
  for_each = local.external_consume

  project      = var.project_id
  subscription = google_pubsub_subscription.external[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}
