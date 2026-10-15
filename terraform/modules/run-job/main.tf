resource "google_cloud_run_v2_job" "this" {
  project             = var.project_id
  name                = var.name
  location            = var.region
  deletion_protection = var.deletion_protection
  labels              = var.labels

  template {
    task_count  = var.task_count
    parallelism = var.parallelism
    labels      = var.labels

    template {
      service_account = var.service_account_email
      max_retries     = var.max_retries
      timeout         = "${var.timeout_seconds}s"

      dynamic "vpc_access" {
        for_each = var.vpc_network == null ? [] : [1]
        content {
          egress = "PRIVATE_RANGES_ONLY"
          network_interfaces {
            network    = var.vpc_network
            subnetwork = var.vpc_subnetwork
          }
        }
      }

      containers {
        image = var.image
        args  = var.args

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }

        dynamic "env" {
          for_each = var.env
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = var.secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

# Cloud Scheduler solo puede ejecutar este job, no el resto del proyecto.
resource "google_cloud_run_v2_job_iam_member" "scheduler" {
  count = var.schedule == null ? 0 : 1

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.this.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.scheduler_service_account_email}"
}

resource "google_cloud_scheduler_job" "this" {
  count = var.schedule == null ? 0 : 1

  project          = var.project_id
  region           = var.region
  name             = "${var.name}-schedule"
  schedule         = var.schedule
  time_zone        = var.time_zone
  attempt_deadline = "320s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/${google_cloud_run_v2_job.this.id}:run"

    oauth_token {
      service_account_email = var.scheduler_service_account_email
    }
  }

  depends_on = [google_cloud_run_v2_job_iam_member.scheduler]
}
