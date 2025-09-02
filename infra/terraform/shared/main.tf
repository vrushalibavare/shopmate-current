terraform {
  # Backend configuration is externalized for security
  # Actual config is stored in AWS Parameter Store and fetched at runtime
  # This prevents sensitive backend details from being stored in the repository
  backend "s3" {}
}

# AWS Provider Configuration with shared tags
provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project     = "ShopMate"
      Environment = "shared"
      ManagedBy   = "Terraform"
      Owner       = "Group1"
      Application = "E-commerce"
    }
  }
}

# ECR Repository - shared across all environments
resource "aws_ecr_repository" "shopmate" {
  name                 = "shopmate"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_lifecycle_policy" "shopmate" {
  repository = aws_ecr_repository.shopmate.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

