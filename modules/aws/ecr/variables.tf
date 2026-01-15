variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "Tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type for the repository (AES256 or KMS)"
  type        = string
  default     = "AES256"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption (required if encryption_type is KMS)"
  type        = string
  default     = null
}

variable "force_delete" {
  description = "Force delete repository even if it contains images"
  type        = bool
  default     = false
}

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle policy to clean up old images"
  type        = bool
  default     = true
}

variable "keep_image_count" {
  description = "Number of images to keep in the repository"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Tags to apply to the repository"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
  }
}