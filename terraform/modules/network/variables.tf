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

variable "app_subnet_cidr" {
  description = "CIDR de la subred privada donde Cloud Run sale con Direct VPC egress."
  type        = string
}

variable "psa_prefix_length" {
  description = "Tamaño del rango reservado para Private Service Access (Cloud SQL)."
  type        = number
  default     = 20
}

variable "flow_logs_sampling" {
  description = "Muestreo de VPC Flow Logs (0 = desactivado)."
  type        = number
  default     = 0
}

variable "nat_log_filter" {
  description = "Qué registra Cloud NAT: ERRORS_ONLY, TRANSLATIONS_ONLY o ALL."
  type        = string
  default     = "ERRORS_ONLY"
}
