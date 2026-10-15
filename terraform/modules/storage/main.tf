resource "google_storage_bucket" "this" {
  project                     = var.project_id
  name                        = var.name
  location                    = upper(var.region)
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy
  labels                      = var.labels

  versioning {
    enabled = true
  }

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_days * 86400
  }

  lifecycle_rule {
    condition {
      age                   = var.nearline_after_days
      matches_storage_class = ["STANDARD"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.noncurrent_versions_days
      with_state                 = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  dynamic "cors" {
    for_each = length(var.cors_origins) > 0 ? [1] : []
    content {
      origin          = var.cors_origins
      method          = ["GET", "PUT", "POST", "HEAD"]
      response_header = ["Content-Type", "x-goog-resumable"]
      max_age_seconds = 3600
    }
  }

  dynamic "logging" {
    for_each = var.access_log_bucket == null ? [] : [1]
    content {
      log_bucket = var.access_log_bucket
    }
  }
}

resource "google_storage_bucket_iam_member" "object_user" {
  for_each = var.object_admins

  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectUser"
  member = each.value
}
