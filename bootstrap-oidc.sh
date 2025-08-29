#!/bin/bash
# Bootstrap shared infrastructure including OIDC role

echo "🔐 Deploying shared infrastructure (ECR + OIDC + State Locking)..."

# Deploy all shared infrastructure
cd infra/terraform/shared
terraform init
terraform apply -auto-approve

# Get the role ARN
ROLE_ARN=$(terraform output -raw github_actions_role_arn)

# ============================================================================
# CREATE SECURE BACKEND CONFIGURATIONS
# ============================================================================
# Store Terraform backend configurations in AWS Parameter Store (encrypted)
# This approach provides:
# - No sensitive data in GitHub repository
# - IAM-controlled access to backend configs
# - Ability to rotate configs without code changes
# - Multi-environment support
echo "🔐 Creating Parameter Store backend configurations..."

# Main terraform backend config (for environment workspaces)
aws ssm put-parameter \
  --name "/terraform/backend/shopmate" \
  --value 'bucket               = "sctp-ce10-tfstate"
key                  = "terraform.tfstate"
region               = "ap-southeast-1"
encrypt              = true
workspace_key_prefix = "shopmate/env"
dynamodb_table       = "terraform-state-locks"' \
  --type "SecureString" \
  --overwrite

# Shared terraform backend config (for shared infrastructure)
aws ssm put-parameter \
  --name "/terraform/backend/shopmate-shared" \
  --value 'bucket         = "sctp-ce10-tfstate"
key            = "shopmate/shared/terraform.tfstate"
region         = "ap-southeast-1"
encrypt        = true
dynamodb_table = "terraform-state-locks"' \
  --type "SecureString" \
  --overwrite

echo "✅ Parameter Store backend configurations created!"
echo ""
echo "✅ Shared infrastructure deployed!"
echo "📋 Add this to GitHub secrets as AWS_GITHUB_ACTIONS_ROLE_ARN:"
echo "$ROLE_ARN"
echo ""
echo "After adding the secret, workflows will use OIDC authentication."