environment              = "qa"
project_id               = "pprov-qa-SUFIJO"
deployer_service_account = "sa-cicd-app@pprov-shared-SUFIJO.iam.gserviceaccount.com"

app_subnet_cidr = "10.20.0.0/24"

# Igual que prod en forma (vCPU dedicada) pero más pequeño y zonal.
db = {
  tier                  = "db-custom-1-3840"
  availability_type     = "ZONAL"
  disk_size_gb          = 20
  backup_retained_count = 7
  pitr_days             = 3
  max_connections       = 100
}

services = {
  frontend = { min_instances = 0, max_instances = 3 }
  api      = { min_instances = 0, max_instances = 5 }
  worker   = { min_instances = 0, max_instances = 3 }
}

rate_limit_per_minute = 600
log_retention_days    = 30
deletion_protection   = false
files_force_destroy   = true
