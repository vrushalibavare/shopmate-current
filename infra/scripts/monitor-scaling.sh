#!/bin/bash

# ShopMate Autoscaling Monitor Script
# Monitors ECS task count and CPU utilization in real-time
# Usage: ./monitor-scaling.sh [environment]
# Example: ./monitor-scaling.sh dev

# Get resource names from Terraform outputs (default to dev environment)
ENV=${1:-dev}
CLUSTER_NAME=$(cd ../terraform && terraform workspace select $ENV && terraform output -raw ecs_cluster_name)
SERVICE_NAME=$(cd ../terraform && terraform workspace select $ENV && terraform output -raw main_service_name)
REGION="ap-southeast-1"

echo "=== ShopMate Autoscaling Monitor ==="
echo "Monitoring ECS service: $SERVICE_NAME"
echo "Cluster: $CLUSTER_NAME"
echo "Press Ctrl+C to stop monitoring"
echo ""

# Monitor task count changes (macOS compatible)
while true; do
  clear
  echo "=== ShopMate Autoscaling Monitor ==="
  echo "Monitoring ECS service: $SERVICE_NAME"
  echo "Cluster: $CLUSTER_NAME"
  echo "Press Ctrl+C to stop monitoring"
  echo ""
  echo "=== Task Count ==="
  aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query "services[0].{desired:desiredCount,running:runningCount}" --region $REGION
  echo ""
  echo "=== Recent CPU Utilization ==="
  aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization --dimensions Name=ServiceName,Value=$SERVICE_NAME Name=ClusterName,Value=$CLUSTER_NAME --start-time $(date -u -v-5M +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Average --region $REGION --query "Datapoints[-1].{Timestamp:Timestamp,CPU:Average}" 2>/dev/null || echo "No recent data"
  echo ""
  echo "Refreshing in 5 seconds..."
  sleep 5
done