output "primary_endpoint" {
  description = "Primary endpoint address for the replication group"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Reader endpoint address for the replication group"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "port" {
  description = "Port number"
  value       = var.port
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.main.id
}

output "replication_group_id" {
  description = "Replication group ID"
  value       = aws_elasticache_replication_group.main.id
}

output "redis_url" {
  description = "Redis-compatible connection URL (without auth)"
  value       = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:${var.port}"
}