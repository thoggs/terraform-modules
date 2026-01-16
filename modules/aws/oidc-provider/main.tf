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

# IAM permissions for Terraform to manage OIDC provider
data "aws_iam_policy_document" "iam_oidc" {
  statement {
    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole"
    ]
    effect    = "Allow"
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"]
  }
}

resource "aws_iam_role_policy" "iam_oidc" {
  name   = "iam-oidc-management"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.iam_oidc.json
}

# RDS permissions for Terraform (always enabled - needed for infra management)
data "aws_iam_policy_document" "rds" {
  statement {
    actions = [
      "rds:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "rds" {
  name   = "rds-management"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.rds.json
}