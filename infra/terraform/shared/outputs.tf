# ============================================================================
# SHARED INFRASTRUCTURE OUTPUTS
# ============================================================================

output "ecr_repository_url" {
  description = "ECR repository URL for Docker image storage"
  value       = aws_ecr_repository.shopmate.repository_url
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}