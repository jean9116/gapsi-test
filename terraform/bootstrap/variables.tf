variable "app_name" {
  description = "Prefijo de la aplicación."
  type        = string
  default     = "pprov"
}

variable "suffix" {
  description = "Sufijo único global de los IDs de proyecto (4-6 caracteres en minúscula)."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{4,6}$", var.suffix))
    error_message = "suffix: de 4 a 6 caracteres [a-z0-9]."
  }
}

variable "billing_account" {
  description = "Cuenta de facturación (XXXXXX-XXXXXX-XXXXXX). Va en terraform.tfvars local, que no se versiona."
  type        = string
  sensitive   = true
}

variable "org_id" {
  description = "Organización (null en cuentas personales sin organización)."
  type        = string
  default     = null
}

variable "folder_id" {
  description = "Carpeta donde crear los proyectos (opcional, solo con organización)."
  type        = string
  default     = null
}

variable "region" {
  description = "Región de Artifact Registry y Cloud Build."
  type        = string
  default     = "us-central1"
}

variable "environments" {
  description = "Ambientes y su presupuesto mensual en USD."
  type        = map(object({ budget_usd = number }))
  default = {
    dev  = { budget_usd = 150 }
    qa   = { budget_usd = 250 }
    prod = { budget_usd = 900 }
  }
}

variable "shared_budget_usd" {
  description = "Presupuesto mensual del proyecto shared."
  type        = number
  default     = 30
}

variable "github_repository" {
  description = <<-EOT
    Repositorio de Cloud Build (2.ª gen.) ya conectado:
    projects/<shared>/locations/<región>/connections/<conexión>/repositories/<repo>.
    La conexión con GitHub requiere autorizar la GitHub App en la consola una vez. null = sin triggers.
  EOT
  type        = string
  default     = null
}

variable "main_branch" {
  description = "Rama principal."
  type        = string
  default     = "main"
}
