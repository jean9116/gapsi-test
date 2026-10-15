resource "google_artifact_registry_repository" "docker" {
  project       = google_project.this["shared"].project_id
  location      = var.region
  repository_id = "${var.app_name}-docker"
  format        = "DOCKER"
  description   = "Imágenes de la plataforma. Una sola imagen se promueve de dev a qa y prod."

  docker_config {
    immutable_tags = true
  }

  # El escaneo automático de Artifact Analysis cuesta 0,26 $ por imagen subida (~40 $/mes con
  # 4 imágenes por merge). Trivy escanea en el pipeline antes del push y corta con CRITICAL.
  vulnerability_scanning_config {
    enablement_config = "DISABLED"
  }

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "borrar-sin-tag-7d"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"
    }
  }

  cleanup_policies {
    id     = "conservar-ultimas-30"
    action = "KEEP"
    most_recent_versions {
      keep_count = 30
    }
  }

  depends_on = [google_project_service.shared]
}

# Cloud Run de cada ambiente lee las imágenes del proyecto shared con su agente de servicio.
resource "google_artifact_registry_repository_iam_member" "run_agents" {
  for_each = toset(local.envs)

  project    = google_artifact_registry_repository.docker.project
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${google_project.this[each.key].number}@serverless-robot-prod.iam.gserviceaccount.com"

  depends_on = [google_project_service.env]
}
