#!/bin/bash

# Gentle Autoscaling Test - Gradual CPU increase for smooth scaling
# This version slowly ramps up load to trigger autoscaling without overwhelming containers
# Usage: ./gentle-autoscaling.sh [environment]
# Example: ./gentle-autoscaling.sh dev

# Get application URL from Terraform outputs (default to dev environment)
ENV=${1:-dev}
APP_URL=$(cd ../terraform && terraform workspace select $ENV && terraform output -raw application_url)

echo "=== Gentle ShopMate Autoscaling Test ==="
echo "Target URL: $APP_URL/stress"
echo "This test gradually increases CPU load for smooth autoscaling"
echo "Press Ctrl+C to stop"
echo ""

# Function to run gentle stress batch
run_gentle_batch() {
  local batch_size=$1
  for i in $(seq 1 $batch_size); do
    curl -k -s "$APP_URL/stress?duration=20000" > /dev/null &
  done
  echo "$(date): Started $batch_size concurrent 20-second gentle stress requests"
}

echo "Phase 1: Starting with 2 requests..."
run_gentle_batch 2
sleep 30

echo "Phase 2: Increasing to 3 requests..."
run_gentle_batch 3
sleep 30

echo "Phase 3: Steady state with 4 requests every 25 seconds..."
while true; do
  sleep 25
  run_gentle_batch 4
done