data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.cluster_id}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

resource "aws_security_group" "main" {
  name        = "${var.cluster_id}-sg"
  description = "Security group for ElastiCache Valkey"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Valkey from allowed security groups"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "Valkey from allowed CIDR blocks"
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_id}-sg"
  })
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = var.cluster_id
  description          = "Valkey cluster for ${var.cluster_id}"
  engine               = "valkey"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = var.port
  parameter_group_name = var.parameter_group_name

  num_cache_clusters = var.num_cache_clusters

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.main.id]

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.transit_encryption_enabled ? var.auth_token : null

  automatic_failover_enabled = var.num_cache_clusters > 1 ? var.automatic_failover_enabled : false
  multi_az_enabled           = var.num_cache_clusters > 1 ? var.multi_az_enabled : false

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  tags = var.tags
}