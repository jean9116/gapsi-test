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
