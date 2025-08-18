#!/bin/bash
set -e

# ShopMate Deployment Script
# Builds and deploys:
# - Main application (shopmate:latest + timestamp)
# - Prometheus monitoring (shopmate:prometheus) if Dockerfile.prometheus exists
# - Updates all ECS services (main app, Prometheus, Grafana)

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${2:-ap-southeast-1}
DOCKERFILE_PATH="."
IMAGE_NAME="shopmate"

echo "🚀 Starting deployment for environment: $ENVIRONMENT in region: $REGION"

# Set terraform directory
TERRAFORM_DIR="terraform/environments/$ENVIRONMENT"

# Clean start - remove lock files and .terraform directory
echo "🧹 Cleaning Terraform state for fresh start..."
rm -rf $TERRAFORM_DIR/.terraform $TERRAFORM_DIR/.terraform.lock.hcl

# Deploy infrastructure
echo "📦 Deploying Terraform infrastructure..."
(cd $TERRAFORM_DIR && terraform init && terraform plan && terraform apply -auto-approve)

# Get ECR repository URL
ECR_URL=$(cd $TERRAFORM_DIR && terraform output -raw ecr_repository_url)
echo "📋 ECR Repository: $ECR_URL"

# Login to ECR
echo "🔐 Logging into ECR..."
if [ -z "$ECR_URL" ]; then
  echo "❌ ECR URL is empty. Please check Terraform outputs."
  exit 1
fi
REGISTRY_URL=$(echo $ECR_URL | cut -d'/' -f1)
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY_URL

# Build multi-architecture images
echo "🏗️ Building multi-architecture Docker images..."
docker buildx create --use --name multiarch-builder 2>/dev/null || docker buildx use multiarch-builder

# Build main application image
echo "📱 Building main application image..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag $ECR_URL:latest \
  --tag $ECR_URL:$(date +%Y%m%d-%H%M%S) \
  --push \
  ../app/

# Build Prometheus image if Dockerfile exists
if [ -f "Dockerfile.prometheus" ]; then
  echo "📊 Building Prometheus image..."
  docker buildx build \
    --platform linux/amd64 \
    --file Dockerfile.prometheus \
    --tag $ECR_URL:prometheus \
    --push \
    ..
else
  echo "⚠️ Dockerfile.prometheus not found, skipping Prometheus build"
fi

# Force ECS services update
echo "🔄 Updating ECS services..."
CLUSTER_NAME=$(cd $TERRAFORM_DIR && terraform output -raw ecs_cluster_name)

# Update main application service
echo "📱 Updating main application service..."
SERVICE_NAME="shopmate-service-$ENVIRONMENT"
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --force-new-deployment \
  --region $REGION

# Update Prometheus service if it exists
echo "📊 Updating Prometheus service..."
PROMETHEUS_SERVICE="prometheus-$ENVIRONMENT"
if aws ecs describe-services --cluster $CLUSTER_NAME --services $PROMETHEUS_SERVICE --region $REGION >/dev/null 2>&1; then
  aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $PROMETHEUS_SERVICE \
    --force-new-deployment \
    --region $REGION
  echo "✅ Prometheus service updated"
else
  echo "⚠️ Prometheus service not found, skipping update"
fi

# Update Grafana service if it exists
echo "📈 Updating Grafana service..."
GRAFANA_SERVICE="grafana-$ENVIRONMENT"
if aws ecs describe-services --cluster $CLUSTER_NAME --services $GRAFANA_SERVICE --region $REGION >/dev/null 2>&1; then
  aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $GRAFANA_SERVICE \
    --force-new-deployment \
    --region $REGION
  echo "✅ Grafana service updated"
else
  echo "⚠️ Grafana service not found, skipping update"
fi

echo "✅ Deployment completed successfully!"
echo "🌐 Application URL: $(cd $TERRAFORM_DIR && terraform output -raw application_url)"
echo "📊 CloudWatch Dashboard: $(cd $TERRAFORM_DIR && terraform output -raw cloudwatch_dashboard_url)"
echo "📈 Grafana Dashboard: $(cd $TERRAFORM_DIR && terraform output -raw grafana_url)"
echo "🔍 Prometheus Metrics: $(cd $TERRAFORM_DIR && terraform output -raw prometheus_url)"