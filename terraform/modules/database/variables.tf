variable "project_id" {
  description = "Proyecto GCP del ambiente."
  type        = string
}

variable "region" {
  description = "Región principal."
  type        = string
}

variable "name" {
  description = "Prefijo de nombres (<app>-<env>)."
  type        = string
}

variable "network_id" {
  description = "VPC con Private Service Access."
  type        = string
}

variable "psa_connection" {
  description = "Conexión PSA; se usa como dependencia explícita."
  type        = string
}

variable "database_version" {
  description = "Versión de PostgreSQL."
  type        = string
  default     = "POSTGRES_18"
}

variable "tier" {
  description = "Tipo de máquina (db-custom-<vCPU>-<MB RAM>)."
  type        = string
}

variable "availability_type" {
  description = "REGIONAL (HA con standby en otra zona y failover automático) o ZONAL."
  type        = string
  validation {
    condition     = contains(["REGIONAL", "ZONAL"], var.availability_type)
    error_message = "availability_type debe ser REGIONAL o ZONAL."
  }
}

variable "disk_size_gb" {
  description = "Tamaño inicial del disco SSD (crece solo con autoresize)."
  type        = number
}

variable "disk_autoresize_limit_gb" {
  description = "Límite del crecimiento automático del disco (0 = sin límite)."
  type        = number
  default     = 0
}

variable "database_name" {
  description = "Nombre de la base de datos de la aplicación."
  type        = string
  default     = "app"
}

variable "backup_retained_count" {
  description = "Número de backups diarios que se conservan."
  type        = number
}

variable "pitr_days" {
  description = "Días de logs de transacciones para Point-In-Time Recovery (1-7)."
  type        = number
}

variable "backup_location" {
  description = "Ubicación de los backups. Una multirregión (p. ej. \"us\") los protege ante la caída de la región."
  type        = string
  default     = null
}

variable "backup_start_time" {
  description = "Hora UTC de inicio del backup diario (HH:MM)."
  type        = string
  default     = "07:00"
}

variable "maintenance_day" {
  description = "Día de mantenimiento (1 = lunes ... 7 = domingo)."
  type        = number
  default     = 7
}

variable "maintenance_hour" {
  description = "Hora UTC de mantenimiento."
  type        = number
  default     = 8
}

variable "max_connections" {
  description = "max_connections de PostgreSQL."
  type        = number
  default     = 200
}

variable "iam_service_accounts" {
  description = "Service accounts que se conectan con autenticación IAM (sin contraseña)."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Protege la instancia contra borrado (Terraform y API)."
  type        = bool
}

variable "admin_password_version" {
  description = "Súbelo para rotar la contraseña del usuario administrador."
  type        = number
  default     = 1
}

variable "labels" {
  description = "Labels comunes."
  type        = map(string)
  default     = {}
}
