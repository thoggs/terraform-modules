output "workload_identity_provider" {
  description = "Full Workload Identity Provider name for GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "workload_identity_pool" {
  description = "Workload Identity Pool name"
  value       = google_iam_workload_identity_pool.github.name
}

output "service_account_email" {
  description = "GitHub Actions Service Account email"
  value       = google_service_account.github_actions.email
}

output "service_account_name" {
  description = "GitHub Actions Service Account name"
  value       = google_service_account.github_actions.name
}