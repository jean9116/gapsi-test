terraform {
  required_version = ">= 1.11"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}
