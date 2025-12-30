output "secret_ids" {
  description = "Map of secret names to secret IDs"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.secret_id }
}

output "secret_names" {
  description = "Map of secret names to full secret names"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.name }
}

output "secret_versions" {
  description = "Map of secret names to latest version names"
  value       = { for k, v in google_secret_manager_secret_version.secrets : k => v.name }
}