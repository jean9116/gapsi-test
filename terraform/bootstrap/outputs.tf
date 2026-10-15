output "projects" {
  description = "IDs de proyecto."
  value       = local.projects
}

output "state_bucket" {
  description = "Bucket del estado de Terraform."
  value       = google_storage_bucket.tfstate.name
}

output "registry" {
  description = "Ruta de Artifact Registry para docker push."
  value       = "${var.region}-docker.pkg.dev/${local.shared}/${google_artifact_registry_repository.docker.repository_id}"
}

output "cicd_app_service_account" {
  description = "SA del pipeline de aplicaciones (deployer_service_account de platform)."
  value       = google_service_account.cicd_app.email
}

output "terraform_service_accounts" {
  description = "SAs de Terraform por ambiente."
  value       = merge({ plan = google_service_account.tf_plan.email }, { for e, sa in google_service_account.tf_apply : e => sa.email })
}
