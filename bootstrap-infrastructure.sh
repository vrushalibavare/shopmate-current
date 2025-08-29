#!/bin/bash
# Bootstrap shared infrastructure including OIDC role

echo "🔐 Creating Parameter Store backend configurations first..."

# ============================================================================
# CREATE SECURE BACKEND CONFIGURATIONS FIRST
# ============================================================================
# Store Terraform backend configurations in AWS Parameter Store (encrypted)
# This approach provides:
# - No sensitive data in GitHub repository
# - IAM-controlled access to backend configs
# - Ability to rotate configs without code changes
# - Multi-environment support

# Main terraform backend config (for environment workspaces)
aws ssm put-parameter \
  --name "/terraform/backend/shopmate" \
  --value 'bucket = "vrush-tfstate-bucket"
key    = "shopmate/env/terraform.tfstate"
region = "ap-southeast-1"
dynamodb_table = "terraform-state-locks"
encrypt = true' \
  --type "SecureString" \
  --overwrite

# Shared terraform backend config (for shared infrastructure)
aws ssm put-parameter \
  --name "/terraform/backend/shopmate-shared" \
  --value 'bucket = "vrush-tfstate-bucket"
key    = "shopmate/shared/terraform.tfstate"
region = "ap-southeast-1"
dynamodb_table = "terraform-state-locks"
encrypt = true' \
  --type "SecureString" \
  --overwrite

echo "✅ Parameter Store backend configurations created!"
echo "🔐 Now deploying shared infrastructure (ECR + OIDC + State Locking)..."

# Deploy all shared infrastructure
cd infra/terraform/shared

# Get backend configuration for shared infrastructure
aws ssm get-parameter \
  --name "/terraform/backend/shopmate-shared" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > backend.hcl

terraform init -reconfigure -backend-config=backend.hcl

# Check if DynamoDB table exists, disable locking if it doesn't
if aws dynamodb describe-table --table-name terraform-state-locks >/dev/null 2>&1; then
  echo "✅ DynamoDB table exists, using state locking"
  terraform apply -auto-approve
else
  echo "⚠️ DynamoDB table doesn't exist, disabling locking for initial deployment"
  terraform apply -auto-approve -lock=false
fi

# Get the role ARN
ROLE_ARN=$(terraform output -raw github_actions_role_arn)
echo ""
echo "✅ Shared infrastructure deployed!"
echo "📋 Add this to GitHub secrets as AWS_GITHUB_ACTIONS_ROLE_ARN:"
echo "$ROLE_ARN"
echo ""
echo "After adding the secret, workflows will use OIDC authentication."