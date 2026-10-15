variable "project_id" {
  description = "Proyecto GCP del ambiente."
  type        = string
}

variable "region" {
  description = "Región del job."
  type        = string
}

variable "name" {
  description = "Nombre del Cloud Run Job."
  type        = string
}

variable "image" {
  description = "Imagen inicial. Después la cambia el pipeline de CI/CD."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/job"
}

variable "args" {
  description = "Argumentos del contenedor (p. ej. el proceso batch a ejecutar)."
  type        = list(string)
  default     = []
}

variable "service_account_email" {
  description = "Service account de runtime del job."
  type        = string
}

variable "scheduler_service_account_email" {
  description = "Service account con la que Cloud Scheduler lanza el job."
  type        = string
}

variable "schedule" {
  description = "Cron (null = sin programación, solo ejecución manual o por evento)."
  type        = string
  default     = null
}

variable "time_zone" {
  description = "Zona horaria del cron."
  type        = string
  default     = "America/Mexico_City"
}

variable "cpu" {
  description = "vCPU por tarea."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memoria por tarea."
  type        = string
  default     = "512Mi"
}

variable "task_count" {
  description = "Tareas por ejecución (paraleliza por lotes)."
  type        = number
  default     = 1
}

variable "parallelism" {
  description = "Tareas simultáneas (limita la presión sobre la BD)."
  type        = number
  default     = 1
}

variable "max_retries" {
  description = "Reintentos por tarea."
  type        = number
  default     = 2
}

variable "timeout_seconds" {
  description = "Timeout por tarea."
  type        = number
  default     = 3600
}

variable "env" {
  description = "Variables de entorno en claro."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Variables de entorno desde Secret Manager: NOMBRE => secret_id."
  type        = map(string)
  default     = {}
}

variable "vpc_network" {
  description = "VPC para Direct VPC egress."
  type        = string
  default     = null
}

variable "vpc_subnetwork" {
  description = "Subred para Direct VPC egress."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Protege el job contra borrado."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels comunes."
  type        = map(string)
  default     = {}
}
