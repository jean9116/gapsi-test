environment              = "prod"
project_id               = "pprov-prod-SUFIJO"
deployer_service_account = "sa-cicd-app@pprov-shared-SUFIJO.iam.gserviceaccount.com"

app_subnet_cidr = "10.30.0.0/23"
# domain        = "proveedores.ejemplo.com"   # con dominio propio; si no, <ip>.sslip.io

# HA regional (standby en otra zona, failover automático), backups en multirregión "us"
# para sobrevivir a la pérdida de la región, PITR de 7 días.
db = {
  tier                     = "db-custom-2-8192"
  availability_type        = "REGIONAL"
  disk_size_gb             = 50
  disk_autoresize_limit_gb = 500
  backup_retained_count    = 30
  pitr_days                = 7
  backup_location          = "us"
  max_connections          = 300
}

# 2.000 concurrentes y hasta 500k operaciones/día: ~6 op/s de media, picos de ~10x.
# Una instancia atiende 80 peticiones simultáneas; max_instances limita también las conexiones a la BD.
services = {
  frontend = { min_instances = 1, max_instances = 10 }
  api      = { min_instances = 2, max_instances = 30, cpu = "1", memory = "1Gi" }
  worker   = { min_instances = 1, max_instances = 10, memory = "1Gi" }
}

rate_limit_per_minute = 1200
log_retention_days    = 90
latency_p95_ms        = 1000
flow_logs_sampling    = 0.1
deletion_protection   = true
files_force_destroy   = false
