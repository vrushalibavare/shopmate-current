#!/bin/bash
set -e

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${2:-ap-southeast-1}
DOCKERFILE_PATH="."
IMAGE_NAME="shopmate"

echo "🚀 Starting deployment for environment: $ENVIRONMENT in region: $REGION"

# Navigate to environment directory
cd terraform/environments/$ENVIRONMENT

# Clean start - remove lock files and .terraform directory
echo "🧹 Cleaning Terraform state for fresh start..."
rm -rf .terraform .terraform.lock.hcl

# Deploy infrastructure
echo "📦 Deploying Terraform infrastructure..."
terraform init
terraform plan
terraform apply -auto-approve

# Get ECR repository URL
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "📋 ECR Repository: $ECR_URL"

# Navigate back to project root
cd ../../..

# Login to ECR
echo "🔐 Logging into ECR..."
if [ -z "$ECR_URL" ]; then
  echo "❌ ECR URL is empty. Please check Terraform outputs."
  exit 1
fi
REGISTRY_URL=$(echo $ECR_URL | cut -d'/' -f1)
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY_URL

# Build multi-architecture image
echo "🏗️ Building multi-architecture Docker image..."
docker buildx create --use --name multiarch-builder 2>/dev/null || docker buildx use multiarch-builder
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag $ECR_URL:latest \
  --tag $ECR_URL:$(date +%Y%m%d-%H%M%S) \
  --push \
  $DOCKERFILE_PATH

# Force ECS service update
echo "🔄 Updating ECS service..."
cd terraform/environments/$ENVIRONMENT
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
SERVICE_NAME="shopmate-service-$ENVIRONMENT"

aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --force-new-deployment \
  --region $REGION

echo "✅ Deployment completed successfully!"
echo "🌐 Application URL: $(terraform output -raw application_url)"
echo "📊 Dashboard: $(terraform output -raw cloudwatch_dashboard_url)"