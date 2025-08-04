#!/bin/bash
set -e

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${2:-ap-southeast-1}

echo "🗑️ Starting destruction for environment: $ENVIRONMENT in region: $REGION"

# Navigate to environment directory
cd terraform/environments/$ENVIRONMENT

# Get resource info before destroying
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

# Clean ECR images
if [ ! -z "$ECR_URL" ]; then
  echo "🧹 Cleaning ECR images..."
  
  # Get all image tags
  IMAGE_TAGS=$(aws ecr list-images --repository-name $REPO_NAME --region $REGION --query 'imageIds[].imageTag' --output text 2>/dev/null || echo "")
  
  if [ ! -z "$IMAGE_TAGS" ]; then
    echo "Deleting images with tags: $IMAGE_TAGS"
    for tag in $IMAGE_TAGS; do
      aws ecr batch-delete-image \
        --repository-name $REPO_NAME \
        --image-ids imageTag=$tag \
        --region $REGION 2>/dev/null || true
    done
  fi
  
  # Delete untagged images
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
  
  echo "✅ ECR images cleaned"
else
  echo "⚠️ ECR repository URL not found, skipping image cleanup"
fi

# Destroy infrastructure
echo "💥 Destroying Terraform infrastructure..."
terraform destroy -auto-approve

echo "✅ Destruction completed successfully!"