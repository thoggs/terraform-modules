variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "image" {
  description = "Container image URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/repo:tag)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "CPU units for the task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "1024"
}

variable "memory" {
  description = "Memory for the task in MB (512, 1024, 2048, etc.)"
  type        = string
  default     = "2048"
}

variable "cpu_architecture" {
  description = "CPU architecture (X86_64 or ARM64). ARM64 uses Graviton and is 20% cheaper."
  type        = string
  default     = "ARM64"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "min_count" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 4
}

variable "enable_autoscaling" {
  description = "Enable CPU-based autoscaling"
  type        = bool
  default     = true
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for autoscaling"
  type        = number
  default     = 70
}

variable "use_spot" {
  description = "Use Fargate Spot capacity provider"
  type        = bool
  default     = false
}

variable "container_insights" {
  description = "Enable Container Insights for the ECS cluster"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Health check endpoint path (leave empty to disable)"
  type        = string
  default     = "/up"
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 60
}

variable "env_vars" {
  description = "Environment variables map"
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Secret environment variables (name => secret ARN)"
  type        = map(string)
  default     = {}
}

variable "secret_arns" {
  description = "List of Secrets Manager ARNs that the task can access"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs that the task can access"
  type        = list(string)
  default     = []
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (leave empty for HTTP only)"
  type        = string
  default     = ""
}

variable "deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = false
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks (required if using public subnets)"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
  }
}