variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Repository ID (usually same as service name)"
  type        = string
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = "Docker repository"
}

variable "format" {
  description = "Repository format (DOCKER, NPM, MAVEN, etc.)"
  type        = string
  default     = "DOCKER"
}

variable "cleanup_policy_dry_run" {
  description = "Run cleanup policies in dry-run mode"
  type        = bool
  default     = false
}

variable "delete_untagged" {
  description = "Delete untagged images"
  type        = bool
  default     = true
}

variable "keep_recent_count" {
  description = "Number of recent images to keep (0 to disable)"
  type        = number
  default     = 2
}

variable "delete_older_than_days" {
  description = "Delete tagged images older than N days (0 to disable)"
  type        = number
  default     = 1
}