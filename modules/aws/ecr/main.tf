resource "aws_ecr_repository" "main" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.kms_key_arn
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "main" {
  count      = var.enable_lifecycle_policy ? 1 : 0
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.keep_image_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}