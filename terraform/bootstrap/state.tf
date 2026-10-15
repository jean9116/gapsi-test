# Bucket del estado de Terraform de todos los stacks (prefijos bootstrap/ y platform/<env>/).
resource "google_storage_bucket" "tfstate" {
  project                     = google_project.this["shared"].project_id
  name                        = "${local.projects.shared}-tfstate"
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 20
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.shared]
}
