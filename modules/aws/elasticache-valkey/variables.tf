variable "cluster_id" {
  description = "ElastiCache cluster identifier"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ElastiCache will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ElastiCache subnet group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect"
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "Valkey engine version"
  type        = string
  default     = "8.0"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "num_cache_clusters" {
  description = "Number of cache clusters (nodes) in the replication group"
  type        = number
  default     = 1
}

variable "port" {
  description = "Port number for Valkey"
  type        = number
  default     = 6379
}

variable "parameter_group_name" {
  description = "Name of the parameter group"
  type        = string
  default     = "default.valkey8"
}

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit (TLS)"
  type        = bool
  default     = false
}

variable "auth_token" {
  description = "Auth token for Valkey (required if transit_encryption_enabled is true)"
  type        = string
  default     = null
  sensitive   = true
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover (requires num_cache_clusters > 1)"
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ (requires num_cache_clusters > 1)"
  type        = bool
  default     = false
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots (0 to disable)"
  type        = number
  default     = 0
}

variable "snapshot_window" {
  description = "Daily time range for snapshots (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately instead of during maintenance window"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
  }
}