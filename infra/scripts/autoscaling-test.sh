#!/bin/bash

# ShopMate Autoscaling Test Script
# This script generates CPU load to test ECS Fargate autoscaling

ALB_URL=$(aws elbv2 describe-load-balancers --names shopmate-alb-dev --query 'LoadBalancers[0].DNSName' --output text --region ap-southeast-1)

echo "=== ShopMate Autoscaling Test ==="
echo "Target URL: https://$ALB_URL/stress"
echo "Starting CPU stress test to trigger autoscaling..."
echo ""

# Generate sustained CPU load with 8 concurrent 20-second stress tests
for i in {1..8}; do
  curl -k -s "https://$ALB_URL/stress?duration=20000" > /dev/null &
done

echo "✅ Stress test initiated with 8 concurrent requests"
echo "📊 Each request runs for 20 seconds of balanced CPU work"
echo ""
echo "Next steps:"
echo "1. Run this script in 2-3 terminals simultaneously for sustained load"
echo "2. Monitor task scaling with: ./monitor-scaling.sh"
echo "3. Scaling should occur within 2-3 minutes when CPU > 70%"
echo "4. Stop all tests to see scale-in after 10-15 minutes"