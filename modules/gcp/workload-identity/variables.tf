variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-pool"
}

variable "pool_display_name" {
  description = "Workload Identity Pool display name"
  type        = string
  default     = "GitHub Actions Pool"
}

variable "pool_description" {
  description = "Workload Identity Pool description"
  type        = string
  default     = "Identity pool for GitHub Actions CI/CD"
}

variable "provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github-provider"
}

variable "provider_display_name" {
  description = "Workload Identity Provider display name"
  type        = string
  default     = "GitHub Provider"
}

variable "provider_description" {
  description = "Workload Identity Provider description"
  type        = string
  default     = "OIDC provider for GitHub Actions"
}

variable "service_account_id" {
  description = "Service Account ID for GitHub Actions"
  type        = string
  default     = "github-actions"
}

variable "service_account_display_name" {
  description = "Service Account display name"
  type        = string
  default     = "GitHub Actions"
}

variable "service_account_description" {
  description = "Service Account description"
  type        = string
  default     = "Service account for GitHub Actions CI/CD"
}

variable "enable_service_account_admin" {
  description = "Enable IAM Service Account Admin role"
  type        = bool
  default     = true
}

variable "enable_secret_manager_admin" {
  description = "Enable Secret Manager Admin role"
  type        = bool
  default     = true
}

variable "enable_workload_identity_admin" {
  description = "Enable Workload Identity Pool Admin role"
  type        = bool
  default     = true
}

variable "enable_project_iam_admin" {
  description = "Enable Project IAM Admin role"
  type        = bool
  default     = true
}

variable "enable_storage_admin" {
  description = "Enable Storage Admin role"
  type        = bool
  default     = true
}