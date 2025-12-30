variable "secrets" {
  description = "Map of secret names to secret values"
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Labels to apply to secrets"
  type        = map(string)
  default     = {}
}