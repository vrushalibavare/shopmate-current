#!/bin/bash
# Bootstrap shared infrastructure including OIDC role

echo "🔐 Deploying shared infrastructure (ECR + OIDC + State Locking)..."

# Deploy all shared infrastructure
cd infra/terraform/shared
terraform init
terraform apply -auto-approve

# Get the role ARN
ROLE_ARN=$(terraform output -raw github_actions_role_arn)
echo ""
echo "✅ Shared infrastructure deployed!"
echo "📋 Add this to GitHub secrets as AWS_GITHUB_ACTIONS_ROLE_ARN:"
echo "$ROLE_ARN"
echo ""
echo "After adding the secret, workflows will use OIDC authentication."