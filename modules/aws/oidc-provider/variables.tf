variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "role_name" {
  description = "IAM role name for GitHub Actions"
  type        = string
  default     = "github-actions"
}

variable "enable_ecs_access" {
  description = "Enable ECS full access for the GitHub Actions role"
  type        = bool
  default     = true
}

variable "enable_secrets_manager_access" {
  description = "Enable Secrets Manager read/write access for the GitHub Actions role"
  type        = bool
  default     = true
}

variable "enable_s3_access" {
  description = "Enable S3 full access for the GitHub Actions role"
  type        = bool
  default     = false
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (leave empty to skip)"
  type        = string
  default     = ""
}

variable "terraform_state_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-locks"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
  }
}