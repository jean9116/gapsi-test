variable "project_id" {
  description = "Proyecto GCP del ambiente."
  type        = string
}

variable "service_accounts" {
  description = "Service accounts de runtime: clave => { descripción, roles a nivel de proyecto }."
  type = map(object({
    description   = string
    project_roles = list(string)
  }))
}

variable "prefix" {
  description = "Prefijo de los account_id (sa-<componente> en un proyecto propio del ambiente)."
  type        = string
  default     = "sa"
}
