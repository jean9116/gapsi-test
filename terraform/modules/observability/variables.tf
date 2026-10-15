variable "project_id" {
  description = "Proyecto GCP del ambiente."
  type        = string
}

variable "name" {
  description = "Prefijo de nombres (<app>-<env>)."
  type        = string
}

variable "notification_emails" {
  description = "Correos que reciben las alertas."
  type        = list(string)
}

variable "log_retention_days" {
  description = "Retención del bucket _Default de Cloud Logging (30 incluidos sin coste)."
  type        = number
  default     = 30
}

variable "manage_default_log_bucket" {
  description = "Gestiona la retención del bucket _Default (false en un proyecto compartido con otras cargas)."
  type        = bool
  default     = true
}

variable "run_services" {
  description = "Servicios Cloud Run a vigilar."
  type        = list(string)
}

variable "run_jobs" {
  description = "Cloud Run Jobs a vigilar."
  type        = list(string)
  default     = []
}

variable "sql_database_id" {
  description = "ID de la instancia para Monitoring (proyecto:instancia)."
  type        = string
}

variable "dlq_subscriptions" {
  description = "Suscripciones de DLQ: cualquier mensaje en ellas es una alerta."
  type        = list(string)
  default     = []
}

variable "work_subscriptions" {
  description = "Suscripciones de trabajo: alerta si el mensaje más antiguo sin confirmar envejece."
  type        = list(string)
  default     = []
}

variable "uptime_host" {
  description = "Host público para los uptime checks."
  type        = string
}

variable "uptime_paths" {
  description = "Rutas a comprobar: nombre => ruta."
  type        = map(string)
  default = {
    frontend = "/"
    api      = "/api/healthz"
  }
}

variable "error_ratio_threshold" {
  description = "Proporción de respuestas 5xx que dispara la alerta."
  type        = number
  default     = 0.05
}

variable "latency_p95_ms" {
  description = "Latencia p95 (ms) que dispara la alerta."
  type        = number
  default     = 1500
}

variable "sql_cpu_threshold" {
  description = "Uso de CPU de Cloud SQL (0-1)."
  type        = number
  default     = 0.8
}

variable "sql_max_connections_alert" {
  description = "Conexiones activas a PostgreSQL que disparan la alerta."
  type        = number
  default     = 160
}

variable "oldest_unacked_seconds" {
  description = "Antigüedad máxima del mensaje más viejo sin procesar."
  type        = number
  default     = 900
}
