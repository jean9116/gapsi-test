terraform {
  required_version = ">= 1.11"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # Configuración parcial: el bucket y el prefijo vienen de environments/<env>/backend.hcl,
  # así cada ambiente tiene su propio estado.
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = local.labels
}
