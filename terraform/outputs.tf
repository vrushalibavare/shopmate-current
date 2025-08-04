# ============================================================================
# TERRAFORM OUTPUTS
# ============================================================================
# Output values used by deployment scripts and for reference

output "ecr_repository_url" {
  description = "ECR repository URL for Docker image storage"
  value       = aws_ecr_repository.shopmate.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name for service deployment"
  value       = "shopmate-${var.environment}"
}

output "application_url" {
  description = "Application URL with HTTPS"
  value       = "https://${var.domain_name}"
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL for monitoring"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=shopmate-${var.environment}"
}