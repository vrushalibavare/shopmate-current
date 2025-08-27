#!/bin/bash

# Resource Consumption Analysis Script
# Analyzes CPU/Memory usage patterns across environments

ENVIRONMENT=${1:-dev}
REGION=${2:-ap-southeast-1}

echo "🔍 Analyzing resource consumption for $ENVIRONMENT environment"
echo "=================================================="

# Get current resource allocation
case $ENVIRONMENT in
  "dev")
    CPU_ALLOCATED=256
    MEMORY_ALLOCATED=512
    ;;
  "uat")
    CPU_ALLOCATED=512
    MEMORY_ALLOCATED=1024
    ;;
  "prod")
    CPU_ALLOCATED=1024
    MEMORY_ALLOCATED=2048
    ;;
esac

echo "📊 Current Allocation:"
echo "  CPU: $CPU_ALLOCATED units"
echo "  Memory: ${MEMORY_ALLOCATED}MB"
echo ""

# Get ECS service details
CLUSTER_NAME="shopmate-ecs-$ENVIRONMENT"
SERVICE_NAME="shopmate-service-$ENVIRONMENT"

echo "🔄 Current Service Status:"
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $REGION \
  --query 'services[0].{RunningCount:runningCount,DesiredCount:desiredCount,Status:status}' \
  --output table

echo ""
echo "📈 Recent CPU/Memory Metrics (last 1 hour):"

# Get CPU utilization
CPU_AVG=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=$SERVICE_NAME Name=ClusterName,Value=$CLUSTER_NAME \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region $REGION \
  --query 'Datapoints[*].Average' \
  --output text | awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "No data"}')

# Get Memory utilization
MEM_AVG=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=$SERVICE_NAME Name=ClusterName,Value=$CLUSTER_NAME \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region $REGION \
  --query 'Datapoints[*].Average' \
  --output text | awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "No data"}')

echo "  Average CPU Usage: ${CPU_AVG}%"
echo "  Average Memory Usage: ${MEM_AVG}%"

# Calculate actual usage
if [[ "$CPU_AVG" != "No data" ]]; then
  CPU_ACTUAL=$(echo "scale=0; $CPU_ALLOCATED * $CPU_AVG / 100" | bc)
  echo "  Actual CPU Used: ~${CPU_ACTUAL} units"
fi

if [[ "$MEM_AVG" != "No data" ]]; then
  MEM_ACTUAL=$(echo "scale=0; $MEMORY_ALLOCATED * $MEM_AVG / 100" | bc)
  echo "  Actual Memory Used: ~${MEM_ACTUAL}MB"
fi

echo ""
echo "💡 Resource Optimization Recommendations:"

# CPU recommendations
if [[ "$CPU_AVG" != "No data" ]]; then
  if (( $(echo "$CPU_AVG < 20" | bc -l) )); then
    echo "  🔽 CPU: Consider reducing from $CPU_ALLOCATED to $((CPU_ALLOCATED/2)) units (currently ${CPU_AVG}%)"
  elif (( $(echo "$CPU_AVG > 80" | bc -l) )); then
    echo "  🔼 CPU: Consider increasing from $CPU_ALLOCATED to $((CPU_ALLOCATED*2)) units (currently ${CPU_AVG}%)"
  else
    echo "  ✅ CPU: Current allocation ($CPU_ALLOCATED units) seems appropriate (${CPU_AVG}%)"
  fi
fi

# Memory recommendations
if [[ "$MEM_AVG" != "No data" ]]; then
  if (( $(echo "$MEM_AVG < 20" | bc -l) )); then
    echo "  🔽 Memory: Consider reducing from ${MEMORY_ALLOCATED}MB to $((MEMORY_ALLOCATED/2))MB (currently ${MEM_AVG}%)"
  elif (( $(echo "$MEM_AVG > 80" | bc -l) )); then
    echo "  🔼 Memory: Consider increasing from ${MEMORY_ALLOCATED}MB to $((MEMORY_ALLOCATED*2))MB (currently ${MEM_AVG}%)"
  else
    echo "  ✅ Memory: Current allocation (${MEMORY_ALLOCATED}MB) seems appropriate (${MEM_AVG}%)"
  fi
fi

echo ""
echo "📊 Dashboard URLs:"
echo "  CloudWatch: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=shopmate-dashboard-$ENVIRONMENT"
echo "  Grafana: https://shopmate.$ENVIRONMENT.sctp-sandbox.com/grafana"