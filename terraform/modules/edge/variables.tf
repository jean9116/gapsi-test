variable "project_id" {
  description = "Proyecto GCP del ambiente."
  type        = string
}

variable "region" {
  description = "Región de los servicios Cloud Run."
  type        = string
}

variable "name" {
  description = "Prefijo de nombres (<app>-<env>)."
  type        = string
}

variable "frontend_service_name" {
  description = "Servicio Cloud Run del frontend."
  type        = string
}

variable "api_service_name" {
  description = "Servicio Cloud Run de la API."
  type        = string
}

variable "api_path_prefix" {
  description = "Prefijo de ruta que se envía a la API."
  type        = string
  default     = "/api"
}

variable "domain" {
  description = "Dominio público. Si es null se usa <ip>.sslip.io para tener HTTPS sin DNS propio."
  type        = string
  default     = null
}

variable "enable_cdn" {
  description = "Cloud CDN para los estáticos del frontend."
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Reglas WAF preconfiguradas (SQLi, XSS, LFI, RCE) de Cloud Armor."
  type        = bool
  default     = true
}

variable "rate_limit_per_minute" {
  description = "Peticiones por minuto y por IP antes de responder 429."
  type        = number
  default     = 600
}

variable "log_sample_rate" {
  description = "Muestreo de logs del balanceador (0-1)."
  type        = number
  default     = 1
}
