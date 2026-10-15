environment              = "dev"
project_id               = "pprov-dev-SUFIJO"
deployer_service_account = "sa-cicd-app@pprov-shared-SUFIJO.iam.gserviceaccount.com"

app_subnet_cidr = "10.10.0.0/24"

# Mínimo coste: tier compartido, zonal, sin instancias calientes.
db = {
  tier                  = "db-g1-small"
  availability_type     = "ZONAL"
  disk_size_gb          = 10
  backup_retained_count = 3
  pitr_days             = 1
  max_connections       = 50
}

services = {
  frontend = { min_instances = 0, max_instances = 2 }
  api      = { min_instances = 0, max_instances = 3 }
  worker   = { min_instances = 0, max_instances = 2 }
}

rate_limit_per_minute = 300
log_retention_days    = 30
deletion_protection   = false
files_force_destroy   = true
