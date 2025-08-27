# ============================================================================
# SHOPMATE TERRAFORM VARIABLES
# ============================================================================
# This file defines all configurable parameters for the ShopMate infrastructure.
# Variables are organized by category for better maintainability.

# ============================================================================
# CORE INFRASTRUCTURE VARIABLES
# ============================================================================

variable "aws_region" {
  description = "The AWS region where all resources will be deployed"
  type        = string
  default     = "ap-southeast-1"

}

variable "environment" {
  description = "The deployment environment (dev, uat, prod). This affects resource naming and scaling parameters. Must be explicitly specified."
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, uat, prod."
  }
}

# ============================================================================
# APPLICATION SCALING VARIABLES
# ============================================================================



# ============================================================================
# DNS AND SSL CERTIFICATE VARIABLES
# ============================================================================

variable "domain_name" {
  description = "Fully qualified domain name for the application (e.g., shopmate.example.com). SSL certificate will be issued for this domain. Must be specified per environment."
  type        = string
}

variable "route53_zone_name" {
  description = "The Route53 hosted zone name (e.g., example.com). Must be the parent domain of the application domain."
  type        = string
  default     = "sctp-sandbox.com"
}

variable "create_route53_zone" {
  description = "Whether to create a new Route53 hosted zone (true) or use an existing one (false). Set to false if you already have a hosted zone for your domain."
  type        = bool
  default     = false
}

variable "image_tag" {
  description = "Docker image tag to deploy. Use commit SHA for immutable deployments or environment-specific tags."
  type        = string
}

variable "app_count_min" {
  description = "Minimum number of ECS tasks for auto-scaling"
  type        = number
}

variable "app_count_max" {
  description = "Maximum number of ECS tasks for auto-scaling"
  type        = number
}

variable "task_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, etc.)"
  type        = string
}

variable "task_memory" {
  description = "Memory for ECS task in MB (512, 1024, 2048, etc.)"
  type        = string
}

# ============================================================================
# VARIABLE USAGE NOTES
# ============================================================================
# 
# Environment-specific recommendations:
# - dev: app_count_min = 1, minimal resources for development
# - uat: app_count_min = 2, moderate resources for testing
# - prod: app_count_min = 3+, production-ready with auto-scaling up to 10 instances
#
# DNS Configuration:
# - If you own 'example.com' and want 'shopmate.example.com':
#   - domain_name = "shopmate.example.com"
#   - route53_zone_name = "example.com"
#   - create_route53_zone = false (if zone already exists)
#
# Regional Considerations:
# - Choose AWS region closest to your users for better performance
# - Ensure the region supports all required AWS services
# - Consider compliance and data residency requirements