# Sufijo aleatorio: el nombre de una instancia borrada no se puede reutilizar durante días,
# y así destruir y reconstruir un ambiente no choca con el nombre anterior.
resource "random_id" "suffix" {
  byte_length = 2
}

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = "${var.name}-pg-${random_id.suffix.hex}"
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    edition                     = "ENTERPRISE"
    tier                        = var.tier
    availability_type           = var.availability_type
    disk_type                   = "PD_SSD"
    disk_size                   = var.disk_size_gb
    disk_autoresize             = true
    disk_autoresize_limit       = var.disk_autoresize_limit_gb
    deletion_protection_enabled = var.deletion_protection
    connector_enforcement       = "REQUIRED"
    user_labels                 = var.labels

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      ssl_mode                                      = "ENCRYPTED_ONLY"
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = var.backup_start_time
      location                       = var.backup_location
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = var.pitr_days

      backup_retention_settings {
        retained_backups = var.backup_retained_count
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = var.maintenance_day
      hour         = var.maintenance_hour
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    database_flags {
      name  = "max_connections"
      value = tostring(var.max_connections)
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
  }

  depends_on = [var.psa_connection]
}

resource "google_sql_database" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.database_name
}

# Las aplicaciones entran con su service account (IAM), sin contraseñas.
resource "google_sql_user" "iam" {
  for_each = var.iam_service_accounts

  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = trimsuffix(each.value, ".gserviceaccount.com")
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# Usuario administrador (migraciones y break-glass). La contraseña es efímera y se escribe
# con atributos write-only: no queda ni en el plan ni en el tfstate, solo en Secret Manager.
ephemeral "random_password" "admin" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "admin_password" {
  project   = var.project_id
  secret_id = "${var.name}-db-admin-password"
  labels    = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin_password" {
  secret                 = google_secret_manager_secret.admin_password.id
  secret_data_wo         = ephemeral.random_password.admin.result
  secret_data_wo_version = var.admin_password_version
}

resource "google_sql_user" "admin" {
  project             = var.project_id
  instance            = google_sql_database_instance.this.name
  name                = "app_admin"
  password_wo         = ephemeral.random_password.admin.result
  password_wo_version = var.admin_password_version
}
