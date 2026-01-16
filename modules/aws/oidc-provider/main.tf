data "aws_caller_identity" "current" {}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = var.tags
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecr_power_user" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "ecs_full_access" {
  count      = var.enable_ecs_access ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_role_policy_attachment" "secrets_manager_read_write" {
  count      = var.enable_secrets_manager_access ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  count      = var.enable_s3_access ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

data "aws_iam_policy_document" "terraform_state" {
  count = var.terraform_state_bucket != "" ? 1 : 0

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${var.terraform_state_bucket}",
      "arn:aws:s3:::${var.terraform_state_bucket}/*"
    ]
  }

  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    effect    = "Allow"
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.terraform_state_lock_table}"]
  }
}

resource "aws_iam_role_policy" "terraform_state" {
  count  = var.terraform_state_bucket != "" ? 1 : 0
  name   = "terraform-state-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.terraform_state[0].json
}

data "aws_iam_policy_document" "pass_role" {
  statement {
    actions   = ["iam:PassRole"]
    effect    = "Allow"
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "pass_role" {
  name   = "ecs-pass-role"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.pass_role.json
}

# Full infrastructure management permissions for Terraform
# This policy grants all necessary permissions for managing AWS infrastructure
data "aws_iam_policy_document" "infra_management" {
  # IAM - for roles, policies, OIDC providers
  statement {
    actions = [
      "iam:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # RDS - databases
  statement {
    actions = [
      "rds:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # CloudWatch Logs
  statement {
    actions = [
      "logs:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # ELB - Load Balancers
  statement {
    actions = [
      "elasticloadbalancing:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # EC2 - Security Groups, VPC, Subnets, etc
  statement {
    actions = [
      "ec2:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # ACM - Certificates
  statement {
    actions = [
      "acm:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # Route53 - DNS (if needed)
  statement {
    actions = [
      "route53:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # CloudWatch - Metrics, Alarms
  statement {
    actions = [
      "cloudwatch:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # Application Auto Scaling
  statement {
    actions = [
      "application-autoscaling:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # Service Discovery
  statement {
    actions = [
      "servicediscovery:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # KMS - for encryption
  statement {
    actions = [
      "kms:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # SNS - notifications
  statement {
    actions = [
      "sns:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # SQS - queues
  statement {
    actions = [
      "sqs:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # ElastiCache - Redis/Valkey
  statement {
    actions = [
      "elasticache:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "infra_management" {
  name   = "terraform-infra-management"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.infra_management.json
}