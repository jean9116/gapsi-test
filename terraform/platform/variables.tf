# ---------- Identidad del ambiente ----------
variable "project_id" {
  description = "Proyecto GCP del ambiente (pprov-<env>-<sufijo>)."
  type        = string
}

variable "environment" {
  description = "Ambiente: dev, qa o prod."
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment debe ser dev, qa o prod."
  }
}

variable "app_name" {
  description = "Prefijo corto de la aplicación en nombres y labels."
  type        = string
  default     = "pprov"
}

variable "region" {
  description = "Región principal. us-central1 por precio; northamerica-south1 (Querétaro) si los usuarios están en México."
  type        = string
  default     = "us-central1"
}

variable "owner" {
  description = "Responsable (label owner)."
  type        = string
  default     = "plataforma"
}

# ---------- Red ----------
variable "app_subnet_cidr" {
  description = "CIDR de la subred privada de aplicaciones (distinto por ambiente)."
  type        = string
}

variable "flow_logs_sampling" {
  description = "Muestreo de VPC Flow Logs (0 = desactivado)."
  type        = number
  default     = 0
}

# ---------- Base de datos ----------
variable "db" {
  description = "Configuración de Cloud SQL."
  type = object({
    tier                     = string
    availability_type        = string
    disk_size_gb             = number
    disk_autoresize_limit_gb = optional(number, 0)
    backup_retained_count    = number
    pitr_days                = number
    backup_location          = optional(string)
    max_connections          = optional(number, 200)
  })
}

# ---------- Cómputo ----------
variable "services" {
  description = "Dimensionamiento de los servicios Cloud Run."
  type = map(object({
    cpu                  = optional(string, "1")
    memory               = optional(string, "512Mi")
    min_instances        = optional(number, 0)
    max_instances        = optional(number, 10)
    concurrency          = optional(number, 80)
    cpu_always_allocated = optional(bool, false)
  }))
  validation {
    condition     = alltrue([for k in ["frontend", "api", "worker"] : contains(keys(var.services), k)])
    error_message = "services debe definir frontend, api y worker."
  }
}

variable "jobs" {
  description = "Procesos batch (Cloud Run Jobs + Cloud Scheduler)."
  type = map(object({
    schedule    = optional(string)
    args        = optional(list(string), [])
    cpu         = optional(string, "1")
    memory      = optional(string, "1Gi")
    task_count  = optional(number, 1)
    parallelism = optional(number, 1)
    max_retries = optional(number, 2)
    timeout_s   = optional(number, 3600)
  }))
  default = {}
}

variable "images" {
  description = "Imágenes iniciales por componente. Tras el primer despliegue las gestiona el pipeline."
  type        = map(string)
  default     = {}
}

# ---------- Mensajería ----------
variable "topics" {
  description = "Topics de eventos; push_path = ruta del worker que los procesa."
  type = map(object({
    push_path = optional(string)
  }))
}

variable "external_apps" {
  description = "Aplicaciones externas que publican/consumen eventos (una SA por app)."
  type = map(object({
    publish_topics = optional(list(string), [])
    consume_topics = optional(list(string), [])
  }))
  default = {}
}

# ---------- Secretos de aplicación ----------
variable "app_secrets" {
  description = <<-EOT
    Secretos de aplicación. generate = true los crea Terraform con un valor aleatorio que no queda
    en el estado (write-only). Con generate = false se crea el secreto vacío y el valor se carga fuera
    de Terraform (gcloud secrets versions add). accessors = SAs que pueden leerlo.
  EOT
  type = map(object({
    generate  = bool
    accessors = list(string)
    env_name  = optional(string)
  }))
  default = {}
}

# ---------- Borde ----------
variable "domain" {
  description = "Dominio público. null = <ip>.sslip.io."
  type        = string
  default     = null
}

variable "enable_cdn" {
  description = "Cloud CDN delante del frontend."
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Reglas WAF de Cloud Armor."
  type        = bool
  default     = true
}

variable "rate_limit_per_minute" {
  description = "Peticiones por minuto y por IP."
  type        = number
  default     = 600
}

# ---------- Observabilidad ----------
variable "notification_emails" {
  description = "Correos de alertas."
  type        = list(string)
}

variable "log_retention_days" {
  description = "Retención de Cloud Logging."
  type        = number
  default     = 30
}

variable "latency_p95_ms" {
  description = "Umbral de alerta de latencia p95."
  type        = number
  default     = 1500
}

# ---------- CI/CD y protección ----------
variable "deployer_service_account" {
  description = "SA del pipeline de aplicaciones (proyecto shared) que despliega imágenes en este ambiente."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Protección contra borrado de BD y servicios (true en prod)."
  type        = bool
}

variable "files_force_destroy" {
  description = "Permite borrar el bucket de archivos con contenido (solo dev/qa)."
  type        = bool
  default     = false
}
