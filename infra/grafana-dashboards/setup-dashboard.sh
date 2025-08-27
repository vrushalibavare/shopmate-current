#!/bin/bash

# Helper script to setup Grafana dashboard with Terraform outputs
# Usage: ./setup-dashboard.sh <environment>
# Example: ./setup-dashboard.sh dev

ENVIRONMENT=${1:-dev}
TERRAFORM_DIR="../terraform"

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "❌ Environment '$ENVIRONMENT' not found"
    echo "Available: dev, uat, prod"
    exit 1
fi

echo "🔍 Getting parameters from Terraform for $ENVIRONMENT environment..."

# Get values from Terraform outputs
cd "$TERRAFORM_DIR"
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null)
SERVICE_NAME=$(terraform output -raw main_service_name 2>/dev/null)
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "ap-southeast-1")
GRAFANA_URL=$(terraform output -raw grafana_url 2>/dev/null)
PROMETHEUS_URL=$(terraform output -raw prometheus_url 2>/dev/null)
CLOUDWATCH_URL=$(terraform output -raw cloudwatch_dashboard_url 2>/dev/null)

if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_NAME" ]; then
    echo "❌ Could not get Terraform outputs. Make sure infrastructure is deployed."
    exit 1
fi

echo "✅ Found Terraform values:"
echo "  Cluster: $CLUSTER_NAME"
echo "  Service: $SERVICE_NAME"
echo "  Region: $AWS_REGION"
echo "  Grafana: $GRAFANA_URL"
echo "  Prometheus: $PROMETHEUS_URL"
echo "  CloudWatch: $CLOUDWATCH_URL"
echo ""

echo "📋 Next steps:"
echo "1. Open Grafana: $GRAFANA_URL (admin/admin123)"
echo "2. Add CloudWatch data source:"
echo "   - Go to Configuration > Data Sources > Add CloudWatch"
echo "   - Set Region: $AWS_REGION"
echo "   - Copy UID from browser URL after saving"
echo "   - Reference: $CLOUDWATCH_URL"
echo "3. Add Prometheus data source:"
echo "   - Go to Configuration > Data Sources > Add Prometheus"
echo "   - Set URL: $PROMETHEUS_URL"
echo "   - Copy UID from browser URL after saving"
echo ""

# Prompt for UIDs
read -p "Enter CloudWatch data source UID: " CLOUDWATCH_UID
read -p "Enter Prometheus data source UID: " PROMETHEUS_UID

if [ -z "$CLOUDWATCH_UID" ] || [ -z "$PROMETHEUS_UID" ]; then
    echo "❌ Both UIDs are required"
    exit 1
fi

echo ""
echo "🔄 Updating dashboard..."

# Go back to dashboard directory and run update script
cd - > /dev/null
cd "$(dirname "$0")"

./update-dashboard.sh "$CLOUDWATCH_UID" "$PROMETHEUS_UID" "$CLUSTER_NAME" "$SERVICE_NAME" "$AWS_REGION"

echo ""
echo "✅ Dashboard updated! Import shopmate-autoscaling.json into Grafana"
echo "📊 Dashboard will show metrics for $ENVIRONMENT environment"