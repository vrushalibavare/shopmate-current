# ============================================================================
# SHOPMATE TERRAFORM MAIN CONFIGURATION
# ============================================================================
# This is the main entry point that orchestrates all infrastructure components.
# Individual components are organized in separate files for better maintainability.

# Terraform and Provider Configuration
terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket               = "sctp-ce10-tfstate"
    key                  = "shopmate/terraform.tfstate"
    region               = "ap-southeast-1"
    encrypt              = true
    workspace_key_prefix = "env"
    dynamodb_table       = "terraform-state-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ShopMate"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Group1"
      Application = "E-commerce"
    }
  }
}

# ============================================================================
# INFRASTRUCTURE COMPONENTS
# ============================================================================
# All infrastructure components are defined in separate files:
#
# - networking.tf    : VPC, subnets, security groups, load balancer
# - dns.tf          : SSL certificates and DNS management  
# - storage.tf      : ECR repository and DynamoDB tables
# - iam.tf          : IAM roles, policies, and secrets management
# - ecs.tf          : ECS cluster, task definitions, and services
# - monitoring.tf   : Prometheus and Grafana monitoring setup
# - autoscaling.tf  : Auto-scaling policies and configuration
# - cloudwatch.tf   : CloudWatch dashboards and monitoring
#
# This modular approach provides:
# - Better organization and maintainability
# - Easier troubleshooting and debugging
# - Clear separation of concerns
# - Simplified code reviews and collaboration