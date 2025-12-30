output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = module.workload_identity.workload_identity_provider
}

output "service_account_email" {
  description = "GitHub Actions Service Account email"
  value       = module.workload_identity.service_account_email
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = module.artifact_registry.repository_url
}

output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = module.cloud_run.url
}

output "cloud_run_service_account" {
  description = "Cloud Run Service Account"
  value       = module.cloud_run.service_account_email
}