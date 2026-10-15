# Tests sin credenciales: plan con providers simulados (mock) contra los tfvars de cada ambiente.
#   terraform test -var-file=../environments/common.tfvars -var-file=../environments/<env>/terraform.tfvars

mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "123456789012"
    }
  }
  mock_resource "google_compute_global_address" {
    defaults = {
      address = "203.0.113.10"
    }
  }
  mock_resource "google_cloud_run_v2_service" {
    defaults = {
      uri = "https://mock-worker.a.run.app"
    }
  }
  mock_resource "google_service_account" {
    defaults = {
      email  = "sa-mock@mock-project.iam.gserviceaccount.com"
      member = "serviceAccount:sa-mock@mock-project.iam.gserviceaccount.com"
      id     = "projects/mock-project/serviceAccounts/sa-mock@mock-project.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_sql_database_instance" {
    defaults = {
      connection_name = "mock-project:us-central1:mock-pg"
    }
  }
  mock_resource "google_secret_manager_secret" {
    defaults = {
      id = "projects/mock-project/secrets/mock"
    }
  }
}


run "plan" {
  command = plan

  assert {
    condition     = module.database.instance_name != "" && !google_project_service.this["sqladmin.googleapis.com"].disable_on_destroy
    error_message = "La BD debe existir y las APIs no se deshabilitan al destruir."
  }

  assert {
    condition     = var.environment != "prod" || var.db.availability_type == "REGIONAL"
    error_message = "Prod debe tener Cloud SQL en HA regional."
  }

  assert {
    condition     = var.environment != "prod" || var.deletion_protection
    error_message = "Prod debe tener protección contra borrado."
  }

  assert {
    condition     = alltrue([for sa, cfg in local.service_accounts : !anytrue([for r in cfg.project_roles : contains(["roles/owner", "roles/editor"], r)])])
    error_message = "Ninguna SA de runtime puede tener roles/owner o roles/editor."
  }

  assert {
    condition     = length(local.service_accounts["frontend"].project_roles) == length(local.telemetry_roles)
    error_message = "El frontend solo debe tener roles de telemetría."
  }
}
