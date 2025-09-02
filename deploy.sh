#!/bin/bash
# Deploy to specific environment
# Usage: ./deploy.sh <environment> <region>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <environment> <region>"
    echo "Example: $0 dev ap-southeast-1"
    exit 1
fi

ENVIRONMENT=$1
REGION=$2

echo "🚀 Deploying to $ENVIRONMENT environment in $REGION..."

cd infra/terraform

# Get backend configuration
aws ssm get-parameter \
  --name "/terraform/backend/shopmate" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > backend.hcl

# Initialize and deploy
terraform init -reconfigure -backend-config=backend.hcl
terraform workspace select $ENVIRONMENT || terraform workspace new $ENVIRONMENT
terraform apply -var-file="terraform.tfvars.$ENVIRONMENT" -auto-approve

echo "✅ Deployment to $ENVIRONMENT completed!"