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

echo "🚀 Starting deployment for environment: $ENVIRONMENT in region: $REGION"

# Validate environment variables
echo "🔍 Validating environment variables..."
if [[ ! "$ENVIRONMENT" =~ ^(dev|uat|prod)$ ]]; then
  echo "❌ Invalid environment: $ENVIRONMENT. Must be dev, uat, or prod"
  exit 1
fi

if [[ ! -f "infra/terraform/terraform.tfvars.$ENVIRONMENT" ]]; then
  echo "❌ Missing tfvars file: infra/terraform/terraform.tfvars.$ENVIRONMENT"
  exit 1
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "❌ AWS credentials not configured or invalid"
  exit 1
fi

echo "✅ Environment validation passed"

# Set terraform directory
TERRAFORM_DIR="infra/terraform"

# Clean local Terraform cache (S3 backend state remains intact)
echo "🧹 Cleaning local Terraform cache for fresh start..."
rm -rf $TERRAFORM_DIR/.terraform $TERRAFORM_DIR/.terraform.lock.hcl

# Initialize and validate terraform configurations
echo "🔍 Initializing and validating Terraform configurations..."
(cd infra/terraform && terraform init && terraform validate)
(cd infra/terraform/shared && terraform init && terraform validate)
echo "✅ Terraform validation passed"

# Deploy shared infrastructure first (ECR repository)
echo "📦 Deploying shared infrastructure..."
(cd infra/terraform/shared && terraform init && terraform apply -auto-approve)

# Deploy environment-specific infrastructure using workspace
echo "📦 Deploying $ENVIRONMENT infrastructure using workspace..."
(cd $TERRAFORM_DIR && 
  terraform init && 
  terraform workspace select $ENVIRONMENT || terraform workspace new $ENVIRONMENT && 
  echo "📍 Current workspace: $(terraform workspace show)" && 
  echo "🎯 Target environment: $ENVIRONMENT" && 
  if [[ "$(terraform workspace show)" != "$ENVIRONMENT" ]]; then 
    echo "❌ Workspace mismatch! Expected $ENVIRONMENT, got $(terraform workspace show)"; 
    exit 1; 
  fi && 
  echo "✅ Workspace confirmed: $(terraform workspace show)" && 
  echo "" && 
  echo "⚠️  DEPLOYMENT CONFIRMATION" && 
  echo "Workspace: $(terraform workspace show)" && 
  echo "Environment: $ENVIRONMENT" && 
  echo "Region: $REGION" && 
  echo "" && 
  read -p "Deploy to $(terraform workspace show) workspace? (yes/no): " confirm && 
  if [[ "$confirm" != "yes" ]]; then 
    echo "❌ Deployment cancelled"; 
    exit 1; 
  fi && 
  terraform plan -var-file="terraform.tfvars.$ENVIRONMENT" && 
  terraform apply -var-file="terraform.tfvars.$ENVIRONMENT" -auto-approve)

# Get ECR repository URL
ECR_URL=$(cd $TERRAFORM_DIR && terraform workspace select $ENVIRONMENT && terraform output -raw ecr_repository_url)
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

# Build application images based on environment
if [ "$ENVIRONMENT" = "dev" ]; then
  echo "📱 Building development image (with shell access)..."
  docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag $ECR_URL:dev-latest \
    --push \
    app/
  
  echo "🔒 Building production image (secure distroless, no shell)..."
  docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --file app/Dockerfile.prod \
    --tag $ECR_URL:prod-latest \
    --push \
    app/
  
  IMAGE_TAG="dev-latest"
else
  echo "🔒 Validating production image exists for $ENVIRONMENT..."
  if ! aws ecr describe-images --repository-name shopmate --image-ids imageTag=prod-latest --region $REGION >/dev/null 2>&1; then
    echo "❌ Production image 'prod-latest' not found. Please run deployment on 'dev' environment first."
    exit 1
  fi
  echo "✅ Production image found, using secure distroless image"
  IMAGE_TAG="prod-latest"
fi

# Update ECS service with environment-specific image tag
echo "🔄 Updating Terraform with environment-specific image tag..."
(cd $TERRAFORM_DIR && terraform workspace select $ENVIRONMENT && terraform apply -var-file="terraform.tfvars.$ENVIRONMENT" -auto-approve)

# Build Prometheus image if Dockerfile exists
if [ -f "infra/Dockerfile.prometheus" ]; then
  echo "📊 Building Prometheus image..."
  docker buildx build \
    --platform linux/amd64 \
    --file infra/Dockerfile.prometheus \
    --tag $ECR_URL:prometheus \
    --push \
    infra/
else
  echo "⚠️ infra/Dockerfile.prometheus not found, skipping Prometheus build"
fi

# Force ECS services update
echo "🔄 Updating ECS services..."
CLUSTER_NAME=$(cd $TERRAFORM_DIR && terraform workspace select $ENVIRONMENT && terraform output -raw ecs_cluster_name)

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
PROMETHEUS_SERVICE=$(cd $TERRAFORM_DIR && terraform workspace select $ENVIRONMENT && terraform output -raw prometheus_service_name)
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $PROMETHEUS_SERVICE \
  --force-new-deployment \
  --region $REGION
echo "✅ Prometheus service updated"

# Update Grafana service if it exists
echo "📈 Updating Grafana service..."
GRAFANA_SERVICE=$(cd $TERRAFORM_DIR && terraform workspace select $ENVIRONMENT && terraform output -raw grafana_service_name)
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $GRAFANA_SERVICE \
  --force-new-deployment \
  --region $REGION
echo "✅ Grafana service updated"

echo "✅ Deployment completed successfully!"
echo "🌐 Application URL: $(cd $TERRAFORM_DIR && terraform workspace select $ENVIRONMENT && terraform output -raw application_url)"
echo "📊 CloudWatch Dashboard: $(cd $TERRAFORM_DIR && terraform workspace select $ENVIRONMENT && terraform output -raw cloudwatch_dashboard_url)"
echo "📈 Grafana Dashboard: $(cd $TERRAFORM_DIR && terraform workspace select $ENVIRONMENT && terraform output -raw grafana_url)"
echo "🔍 Prometheus Metrics: $(cd $TERRAFORM_DIR && terraform workspace select $ENVIRONMENT && terraform output -raw prometheus_url)"