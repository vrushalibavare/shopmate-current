#!/bin/bash

# Usage: ./update-dashboard.sh <cloudwatch_uid> <prometheus_uid> <cluster_name> <service_name> <aws_region>

CLOUDWATCH_UID=$1
PROMETHEUS_UID=$2
CLUSTER_NAME=$3
SERVICE_NAME=$4
AWS_REGION=$5

if [ $# -ne 5 ]; then
    echo "Usage: $0 <cloudwatch_uid> <prometheus_uid> <cluster_name> <service_name> <aws_region>"
    echo "Example: $0 abc123 def456 shopmate-dev shopmate-service-dev ap-southeast-1"
    exit 1
fi

# Update the dashboard JSON
sed -i.bak \
    -e "s/bevn5kqdatc00f/$CLOUDWATCH_UID/g" \
    -e "s/eevn5i5677474d/$PROMETHEUS_UID/g" \
    -e "s/shopmate-dev/$CLUSTER_NAME/g" \
    -e "s/shopmate-service-dev/$SERVICE_NAME/g" \
    -e "s/\"region\": \"default\"/\"region\": \"$AWS_REGION\"/g" \
    shopmate-autoscaling.json

echo "Dashboard updated successfully!"
echo "Import the updated shopmate-autoscaling.json into Grafana"