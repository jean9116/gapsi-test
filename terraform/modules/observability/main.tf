resource "google_monitoring_notification_channel" "email" {
  for_each = toset(var.notification_emails)

  project      = var.project_id
  display_name = "${var.name} ${each.value}"
  type         = "email"
  labels = {
    email_address = each.value
  }
}

locals {
  channels = [for c in google_monitoring_notification_channel.email : c.id]

  run_filter = join(" OR ", [for s in var.run_services : "resource.label.service_name = \"${s}\""])
  job_filter = join(" OR ", [for j in var.run_jobs : "resource.label.job_name = \"${j}\""])
  dlq_filter = join(" OR ", [for s in var.dlq_subscriptions : "resource.label.subscription_id = \"${s}\""])
  sub_filter = join(" OR ", [for s in var.work_subscriptions : "resource.label.subscription_id = \"${s}\""])
  sql_filter = "resource.type = \"cloudsql_database\" AND resource.label.database_id = \"${var.sql_database_id}\""
}

# Retención de logs del proyecto (más de 30 días tiene coste por GiB-mes).
# Desactivable al desplegar en un proyecto compartido: el bucket _Default es de todo el proyecto.
resource "google_logging_project_bucket_config" "default" {
  count = var.manage_default_log_bucket ? 1 : 0

  project        = var.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = var.log_retention_days
}

# Métrica de logs: errores de aplicación (severity >= ERROR) en Cloud Run.
resource "google_logging_metric" "app_errors" {
  project = var.project_id
  name    = "${var.name}-app-errors"
  filter  = "resource.type = (\"cloud_run_revision\" OR \"cloud_run_job\") AND severity >= ERROR"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

# --- Cloud Run ---
resource "google_monitoring_alert_policy" "run_5xx" {
  project               = var.project_id
  display_name          = "[${var.name}] Cloud Run: ratio 5xx > ${var.error_ratio_threshold * 100}%"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "5xx / total"
    condition_threshold {
      filter                  = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.label.response_code_class = \"5xx\" AND (${local.run_filter})"
      denominator_filter      = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND (${local.run_filter})"
      comparison              = "COMPARISON_GT"
      threshold_value         = var.error_ratio_threshold
      duration                = "300s"
      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.service_name"]
      }
      denominator_aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }

  documentation {
    content   = "Revisar Error Reporting y los logs de la revisión. Si coincide con un despliegue, hacer rollback: `gcloud run services update-traffic <svc> --to-revisions=<anterior>=100`."
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "run_latency" {
  project               = var.project_id
  display_name          = "[${var.name}] Cloud Run: latencia p95 > ${var.latency_p95_ms} ms"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "p95"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_latencies\" AND (${local.run_filter})"
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_p95_ms
      duration        = "300s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }
}

resource "google_monitoring_alert_policy" "app_errors" {
  project               = var.project_id
  display_name          = "[${var.name}] Errores de aplicación en logs"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "severity >= ERROR > 10/min"
    condition_threshold {
      filter          = "resource.type = one_of(\"cloud_run_revision\", \"cloud_run_job\") AND metric.type = \"logging.googleapis.com/user/${google_logging_metric.app_errors.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  documentation {
    content   = "Los errores agrupados están en Error Reporting (consola > Error Reporting)."
    mime_type = "text/markdown"
  }
}

# --- Cloud SQL ---
resource "google_monitoring_alert_policy" "sql" {
  project               = var.project_id
  display_name          = "[${var.name}] Cloud SQL: saturación"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "CPU > ${var.sql_cpu_threshold * 100}%"
    condition_threshold {
      filter          = "${local.sql_filter} AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.sql_cpu_threshold
      duration        = "600s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  conditions {
    display_name = "Memoria > 90%"
    condition_threshold {
      filter          = "${local.sql_filter} AND metric.type = \"cloudsql.googleapis.com/database/memory/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.9
      duration        = "600s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  conditions {
    display_name = "Disco > 85%"
    condition_threshold {
      filter          = "${local.sql_filter} AND metric.type = \"cloudsql.googleapis.com/database/disk/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85
      duration        = "300s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  conditions {
    display_name = "Conexiones > ${var.sql_max_connections_alert}"
    condition_threshold {
      filter          = "${local.sql_filter} AND metric.type = \"cloudsql.googleapis.com/database/postgresql/num_backends\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.sql_max_connections_alert
      duration        = "300s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.database_id"]
      }
    }
  }

  conditions {
    display_name = "Instancia caída"
    condition_threshold {
      filter          = "${local.sql_filter} AND metric.type = \"cloudsql.googleapis.com/database/up\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "180s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MIN"
      }
    }
  }
}

# --- Pub/Sub ---
resource "google_monitoring_alert_policy" "dlq" {
  count = length(var.dlq_subscriptions) > 0 ? 1 : 0

  project               = var.project_id
  display_name          = "[${var.name}] Pub/Sub: mensajes en DLQ"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "DLQ con mensajes"
    condition_threshold {
      filter          = "resource.type = \"pubsub_subscription\" AND metric.type = \"pubsub.googleapis.com/subscription/num_undelivered_messages\" AND (${local.dlq_filter})"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "60s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  documentation {
    content   = "Revisar el mensaje con `gcloud pubsub subscriptions pull <dlq-sub> --limit=5`, corregir la causa y reinyectarlo en el topic original."
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "backlog" {
  count = length(var.work_subscriptions) > 0 ? 1 : 0

  project               = var.project_id
  display_name          = "[${var.name}] Pub/Sub: backlog atascado"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "Mensaje más antiguo > ${var.oldest_unacked_seconds}s"
    condition_threshold {
      filter          = "resource.type = \"pubsub_subscription\" AND metric.type = \"pubsub.googleapis.com/subscription/oldest_unacked_message_age\" AND (${local.sub_filter})"
      comparison      = "COMPARISON_GT"
      threshold_value = var.oldest_unacked_seconds
      duration        = "300s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }
}

# --- Batch ---
resource "google_monitoring_alert_policy" "job_failed" {
  count = length(var.run_jobs) > 0 ? 1 : 0

  project               = var.project_id
  display_name          = "[${var.name}] Cloud Run Job fallido"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "Ejecución fallida"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_job\" AND metric.type = \"run.googleapis.com/job/completed_execution_count\" AND metric.label.result = \"failed\" AND (${local.job_filter})"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.job_name"]
      }
    }
  }

  documentation {
    content   = "Ver la ejecución con `gcloud run jobs executions list --job <job>` y relanzar con `gcloud run jobs execute <job>` cuando se corrija."
    mime_type = "text/markdown"
  }
}

# --- Disponibilidad externa ---
resource "google_monitoring_uptime_check_config" "this" {
  for_each = var.uptime_paths

  project          = var.project_id
  display_name     = "${var.name}-${each.key}"
  timeout          = "10s"
  period           = "60s"
  selected_regions = ["USA_IOWA", "USA_VIRGINIA", "USA_OREGON"]

  http_check {
    path           = each.value
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.uptime_host
    }
  }
}

resource "google_monitoring_alert_policy" "uptime" {
  for_each = var.uptime_paths

  project               = var.project_id
  display_name          = "[${var.name}] Uptime ${each.key} caído"
  combiner              = "OR"
  notification_channels = local.channels

  conditions {
    display_name = "Falla desde 2+ regiones"
    condition_threshold {
      filter          = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.label.check_id = \"${google_monitoring_uptime_check_config.this[each.key].uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "120s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.host"]
      }
    }
  }
}

resource "google_monitoring_dashboard" "this" {
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${var.name} - plataforma"
    mosaicLayout = {
      columns = 12
      tiles = [
        { xPos = 0, yPos = 0, width = 6, height = 4, widget = {
          title = "Cloud Run: peticiones/s por servicio y clase"
          xyChart = { dataSets = [{ plotType = "STACKED_AREA", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_RATE", crossSeriesReducer = "REDUCE_SUM", groupByFields = ["resource.label.service_name", "metric.label.response_code_class"] }
        } } }] } } },
        { xPos = 6, yPos = 0, width = 6, height = 4, widget = {
          title = "Cloud Run: latencia p95 (ms)"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_latencies\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_DELTA", crossSeriesReducer = "REDUCE_PERCENTILE_95", groupByFields = ["resource.label.service_name"] }
        } } }] } } },
        { xPos = 0, yPos = 4, width = 6, height = 4, widget = {
          title = "Cloud Run: instancias activas"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/container/instance_count\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MAX", crossSeriesReducer = "REDUCE_SUM", groupByFields = ["resource.label.service_name"] }
        } } }] } } },
        { xPos = 6, yPos = 4, width = 6, height = 4, widget = {
          title = "Cloud SQL: CPU y memoria"
          xyChart = { dataSets = [
            { plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
              filter      = "${local.sql_filter} AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
              aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MEAN" }
            } } },
            { plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
              filter      = "${local.sql_filter} AND metric.type = \"cloudsql.googleapis.com/database/memory/utilization\""
              aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MEAN" }
            } } }
        ] } } },
        { xPos = 0, yPos = 8, width = 6, height = 4, widget = {
          title = "Cloud SQL: conexiones"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "${local.sql_filter} AND metric.type = \"cloudsql.googleapis.com/database/postgresql/num_backends\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MEAN", crossSeriesReducer = "REDUCE_SUM" }
        } } }] } } },
        { xPos = 6, yPos = 8, width = 6, height = 4, widget = {
          title = "Pub/Sub: mensajes sin entregar"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "resource.type = \"pubsub_subscription\" AND metric.type = \"pubsub.googleapis.com/subscription/num_undelivered_messages\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MAX", crossSeriesReducer = "REDUCE_SUM", groupByFields = ["resource.label.subscription_id"] }
        } } }] } } },
      ]
    }
  })
}
