#!/bin/bash
set -e

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${2:-ap-southeast-1}

echo "🗑️ Starting destruction for environment: $ENVIRONMENT in region: $REGION"

# Navigate to terraform directory
cd infra/terraform

# Select workspace and get resource info before destroying
terraform workspace select $ENVIRONMENT 2>/dev/null || { echo "Workspace $ENVIRONMENT not found"; exit 1; }
ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
REPO_NAME=$(echo $ECR_URL | cut -d'/' -f2 2>/dev/null || echo "shopmate")
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
SERVICE_NAME="shopmate-service-$ENVIRONMENT"

# Stop ECS service to release image references
if [ ! -z "$CLUSTER_NAME" ]; then
  echo "⏹️ Stopping ECS service to release image references..."
  aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --desired-count 0 \
    --region $REGION 2>/dev/null || true
  
  echo "⏳ Waiting for tasks to stop..."
  aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $REGION 2>/dev/null || true
  
  sleep 30  # Additional wait for task cleanup
fi

# Clean ECR images (only environment-specific ones, preserve prod-latest for promotion)
if [ ! -z "$ECR_URL" ]; then
  echo "🧹 Cleaning environment-specific ECR images..."
  
  # Only delete environment-specific images, preserve prod-latest for UAT/PROD
  ENV_TAG="$ENVIRONMENT-latest"
  
  echo "Deleting $ENV_TAG image (preserving prod-latest for promotion)..."
  aws ecr batch-delete-image \
    --repository-name $REPO_NAME \
    --image-ids imageTag=$ENV_TAG \
    --region $REGION 2>/dev/null || true
  
  # Delete untagged images only
  UNTAGGED_IMAGES=$(aws ecr list-images --repository-name $REPO_NAME --region $REGION --filter tagStatus=UNTAGGED --query 'imageIds[].imageDigest' --output text 2>/dev/null || echo "")
  
  if [ ! -z "$UNTAGGED_IMAGES" ]; then
    echo "Deleting untagged images..."
    for digest in $UNTAGGED_IMAGES; do
      aws ecr batch-delete-image \
        --repository-name $REPO_NAME \
        --image-ids imageDigest=$digest \
        --region $REGION 2>/dev/null || true
    done
  fi
  
  echo "✅ Environment-specific images cleaned (prod-latest preserved)"
else
  echo "⚠️ ECR repository URL not found, skipping image cleanup"
fi

# Destroy infrastructure (preserve OIDC role for future deployments)
echo "💥 Destroying Terraform infrastructure (preserving OIDC role)..."
terraform destroy -var-file="terraform.tfvars.$ENVIRONMENT" -auto-approve

echo "⚠️  OIDC role preserved for future deployments"
echo "To destroy OIDC role: cd infra/terraform/shared && terraform destroy"

echo "✅ Destruction completed successfully!"