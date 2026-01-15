output "endpoint" {
  description = "RDS endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "RDS hostname"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Name of the database"
  value       = aws_db_instance.main.db_name
}

output "username" {
  description = "Master username"
  value       = aws_db_instance.main.username
}

output "arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.main.id
}

output "security_group_id" {
  description = "Security group ID for the RDS instance"
  value       = aws_security_group.main.id
}

output "subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${aws_db_instance.main.username}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the master password (when using manage_master_user_password)"
  value       = try(aws_db_instance.main.master_user_secret[0].secret_arn, null)
}