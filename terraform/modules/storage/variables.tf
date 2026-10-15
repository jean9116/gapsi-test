variable "project_id" {
  description = "Proyecto GCP del ambiente."
  type        = string
}

variable "region" {
  description = "Región del bucket."
  type        = string
}

variable "name" {
  description = "Nombre del bucket (único global)."
  type        = string
}

variable "nearline_after_days" {
  description = "Días tras los que un objeto pasa a Nearline."
  type        = number
  default     = 90
}

variable "noncurrent_versions_days" {
  description = "Días que se guardan las versiones anteriores de un objeto."
  type        = number
  default     = 30
}

variable "soft_delete_days" {
  description = "Retención de soft delete (0-90 días)."
  type        = number
  default     = 7
}

variable "cors_origins" {
  description = "Orígenes permitidos para subir/descargar con URLs firmadas desde el navegador."
  type        = list(string)
  default     = []
}

variable "object_admins" {
  description = "Miembros con lectura/escritura de objetos (roles/storage.objectUser)."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Permite destruir el bucket con objetos (solo dev/qa)."
  type        = bool
  default     = false
}

variable "access_log_bucket" {
  description = "Bucket donde dejar los logs de uso (opcional)."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels comunes."
  type        = map(string)
  default     = {}
}
