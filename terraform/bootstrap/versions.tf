terraform {
  required_version = ">= 1.11"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
  # Primer apply con estado local. Después: make bootstrap-migrate (crea backend.tf y mueve el estado al bucket).
}

provider "google" {
  region         = var.region
  default_labels = { app = var.app_name, managed-by = "terraform", component = "bootstrap" }
}

# La API de presupuestos exige un proyecto de cuota cuando se usan credenciales de usuario.
provider "google" {
  alias                 = "billing"
  region                = var.region
  billing_project       = local.projects.shared
  user_project_override = true
}
