#!/bin/bash

# Grafana Dashboard Update Script
# 
# NOTE: UIDs change between Grafana instances, cluster/service names change per environment
#
# Usage: ./update-dashboard.sh <cloudwatch_uid> <prometheus_uid> <cluster_name> <service_name> <aws_region>
# 
# Examples:
#   Dev:  ./update-dashboard.sh abc123 def456 shopmate-ecs-dev shopmate-service-dev ap-southeast-1
#   UAT:  ./update-dashboard.sh abc123 def456 shopmate-ecs-uat shopmate-service-uat ap-southeast-1
#   Prod: ./update-dashboard.sh abc123 def456 shopmate-ecs-prod shopmate-service-prod ap-southeast-1

CLOUDWATCH_UID=$1
PROMETHEUS_UID=$2
CLUSTER_NAME=$3
SERVICE_NAME=$4
AWS_REGION=$5

if [ $# -ne 5 ]; then
    echo "Usage: $0 <cloudwatch_uid> <prometheus_uid> <cluster_name> <service_name> <aws_region>"
    echo "Examples:"
    echo "  Dev:  $0 abc123 def456 shopmate-ecs-dev shopmate-service-dev ap-southeast-1"
    echo "  UAT:  $0 abc123 def456 shopmate-ecs-uat shopmate-service-uat ap-southeast-1"
    echo "  Prod: $0 abc123 def456 shopmate-ecs-prod shopmate-service-prod ap-southeast-1"
    exit 1
fi

# Current values in the dashboard (known values)
CURRENT_CLOUDWATCH_UID="aevtysde4f4e8a"
CURRENT_PROMETHEUS_UID="cevtyu88ul62ob"
CURRENT_CLUSTER="shopmate-dev"
CURRENT_SERVICE="shopmate-service-dev"

echo "Detected current values:"
echo "  CloudWatch UID: $CURRENT_CLOUDWATCH_UID"
echo "  Prometheus UID: $CURRENT_PROMETHEUS_UID"
echo "  Cluster: $CURRENT_CLUSTER"
echo "  Service: $CURRENT_SERVICE"
echo ""
echo "Updating to new values:"
echo "  CloudWatch UID: $CLOUDWATCH_UID"
echo "  Prometheus UID: $PROMETHEUS_UID"
echo "  Cluster: $CLUSTER_NAME"
echo "  Service: $SERVICE_NAME"
echo "  Region: $AWS_REGION"
echo ""

# Update the dashboard JSON with auto-detected values
sed -i '' \
    -e "s/$CURRENT_CLOUDWATCH_UID/$CLOUDWATCH_UID/g" \
    -e "s/$CURRENT_PROMETHEUS_UID/$PROMETHEUS_UID/g" \
    -e "s/$CURRENT_CLUSTER/$CLUSTER_NAME/g" \
    -e "s/$CURRENT_SERVICE/$SERVICE_NAME/g" \
    -e "s/\"region\": \"default\"/\"region\": \"$AWS_REGION\"/g" \
    shopmate-autoscaling.json

echo "Dashboard updated successfully!"
echo "Import the updated shopmate-autoscaling.json into Grafana"