resource "google_cloud_run_v2_service" "this" {
  project              = var.project_id
  name                 = var.name
  location             = var.region
  ingress              = var.ingress
  deletion_protection  = var.deletion_protection
  invoker_iam_disabled = var.public_via_lb
  labels               = var.labels

  template {
    service_account                  = var.service_account_email
    max_instance_request_concurrency = var.concurrency
    timeout                          = "${var.timeout_seconds}s"
    labels                           = var.labels

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    dynamic "vpc_access" {
      for_each = var.vpc_network == null ? [] : [1]
      content {
        egress = var.vpc_egress
        network_interfaces {
          network    = var.vpc_network
          subnetwork = var.vpc_subnetwork
        }
      }
    }

    containers {
      image = var.image

      ports {
        container_port = var.port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = !var.cpu_always_allocated
        startup_cpu_boost = true
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

      dynamic "startup_probe" {
        for_each = var.health_path == null ? [] : [1]
        content {
          initial_delay_seconds = 0
          period_seconds        = 5
          timeout_seconds       = 3
          failure_threshold     = 12
          http_get {
            path = var.health_path
          }
        }
      }

      dynamic "liveness_probe" {
        for_each = var.health_path == null ? [] : [1]
        content {
          period_seconds    = 30
          timeout_seconds   = 5
          failure_threshold = 3
          http_get {
            path = var.health_path
          }
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # La imagen la despliega el pipeline (cicd/). Terraform es dueño del resto de la configuración.
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = var.invokers

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = each.value
}
