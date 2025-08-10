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
  description = "The deployment environment (dev, uat, prod). This affects resource naming and scaling parameters."
  type        = string
  default     = "dev"
}

# ============================================================================
# APPLICATION SCALING VARIABLES
# ============================================================================

variable "app_count" {
  description = "Initial number of ECS tasks (containers) to run. This serves as the minimum capacity for auto-scaling."
  type        = number
  default     = 1
  
  validation {
    condition = var.app_count >= 1 && var.app_count <= 10
    error_message = "App count must be between 1 and 10."
  }
}

# ============================================================================
# DNS AND SSL CERTIFICATE VARIABLES
# ============================================================================

variable "domain_name" {
  description = "Fully qualified domain name for the application (e.g., shopmate.example.com). SSL certificate will be issued for this domain."
  type        = string
  default     = "shopmate-app.sctp-sandbox.com"
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

# ============================================================================
# VARIABLE USAGE NOTES
# ============================================================================
# 
# Environment-specific recommendations:
# - dev: app_count = 1, minimal resources for development
# - uat: app_count = 2, moderate resources for testing
# - prod: app_count = 3+, production-ready with auto-scaling up to 10 instances
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