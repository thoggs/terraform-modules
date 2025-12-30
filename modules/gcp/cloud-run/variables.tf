variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
}

variable "image" {
  description = "Container image URL (e.g., us-central1-docker.pkg.dev/project/repo/image:tag)"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "CPU limit (e.g., '1', '2')"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit (e.g., '512Mi', '1Gi')"
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum number of instances (0 = scale to zero)"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "cpu_idle" {
  description = "Enable CPU idle billing (CPU only charged during requests)"
  type        = bool
  default     = true
}

variable "startup_cpu_boost" {
  description = "Enable startup CPU boost for faster cold starts"
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Request timeout"
  type        = string
  default     = "300s"
}

variable "ingress" {
  description = "Ingress setting (INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER)"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/api/health"
}

variable "startup_probe_initial_delay" {
  description = "Initial delay for startup probe in seconds"
  type        = number
  default     = 0
}

variable "startup_probe_period" {
  description = "Period between startup probe checks in seconds"
  type        = number
  default     = 2
}

variable "startup_probe_failure_threshold" {
  description = "Number of failures before container is considered unhealthy"
  type        = number
  default     = 10
}

variable "liveness_probe_period" {
  description = "Period between liveness probe checks in seconds"
  type        = number
  default     = 30
}

variable "liveness_probe_failure_threshold" {
  description = "Number of failures before container is restarted"
  type        = number
  default     = 3
}

variable "env_vars" {
  description = "Environment variables map"
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Secret environment variables (name => {secret_id, version})"
  type = map(object({
    secret_id = string
    version   = string
  }))
  default = {}
}

variable "allow_public_access" {
  description = "Allow unauthenticated access to the service"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "custom_domain" {
  description = "Custom domain for the service (leave empty to skip)"
  type        = string
  default     = ""
}