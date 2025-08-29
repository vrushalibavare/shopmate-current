#!/bin/bash
# ============================================================================
# SECURITY VERIFICATION SCRIPT
# ============================================================================
# This script verifies the security implementation of the ShopMate deployment
# by testing container capabilities and access restrictions across environments
#
# Tests performed:
# 1. ECS Exec access verification
# 2. Container shell capabilities testing
# 3. Package manager availability check
# 4. File system permissions verification
# 5. Network access validation
# ============================================================================

set -e

ENVIRONMENT=${1:-dev}
REGION=${2:-ap-southeast-1}

echo "🔒 Security Verification for Environment: $ENVIRONMENT"
echo "=============================================="

# Get cluster and service information
cd infra/terraform
terraform workspace select $ENVIRONMENT >/dev/null 2>&1
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
SERVICE_NAME="shopmate-service-$ENVIRONMENT"

echo "📋 Cluster: $CLUSTER_NAME"
echo "📋 Service: $SERVICE_NAME"

# Get running task ARN
echo "🔍 Finding running task..."
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --desired-status RUNNING \
  --region $REGION \
  --query 'taskArns[0]' \
  --output text)

if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
  echo "❌ No running tasks found for service $SERVICE_NAME"
  exit 1
fi

echo "✅ Found running task: $(basename $TASK_ARN)"

# Test 1: ECS Exec Access
echo ""
echo "🧪 Test 1: ECS Exec Access"
echo "-------------------------"
if aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ARN \
  --container shopmate-app \
  --interactive \
  --command "echo 'ECS Exec access verified'" \
  --region $REGION >/dev/null 2>&1; then
  echo "✅ ECS Exec access available"
else
  echo "❌ ECS Exec access denied"
fi

# Test 2: Shell Capabilities
echo ""
echo "🧪 Test 2: Shell Capabilities ($ENVIRONMENT environment)"
echo "----------------------------------------"
echo "Testing available shell and commands..."

# Create a comprehensive shell test
cat > /tmp/shell-test.sh << 'EOF'
#!/bin/sh
echo "=== Shell Information ==="
echo "Shell: $0"
echo "User: $(whoami 2>/dev/null || echo 'unknown')"
echo "Working Directory: $(pwd)"
echo ""

echo "=== Available Commands ==="
for cmd in ls cat ps top wget curl apk apt yum npm node; do
  if command -v $cmd >/dev/null 2>&1; then
    echo "✅ $cmd: $(command -v $cmd)"
  else
    echo "❌ $cmd: not available"
  fi
done
echo ""

echo "=== File System Access ==="
echo "Root directory contents:"
ls -la / 2>/dev/null | head -10 || echo "❌ Cannot list root directory"
echo ""

echo "=== Process Information ==="
ps aux 2>/dev/null | head -5 || ps 2>/dev/null | head -5 || echo "❌ Cannot list processes"
echo ""

echo "=== Network Capabilities ==="
if command -v wget >/dev/null 2>&1; then
  wget -q --spider https://www.google.com && echo "✅ External network access" || echo "❌ No external network access"
elif command -v curl >/dev/null 2>&1; then
  curl -s --connect-timeout 5 https://www.google.com >/dev/null && echo "✅ External network access" || echo "❌ No external network access"
else
  echo "❌ No network testing tools available"
fi
EOF

# Execute the shell test
echo "Executing comprehensive security test..."
aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ARN \
  --container shopmate-app \
  --interactive \
  --command "sh -c '$(cat /tmp/shell-test.sh)'" \
  --region $REGION 2>/dev/null || echo "❌ Could not execute comprehensive test"

# Test 3: Security Summary
echo ""
echo "🔒 Security Summary for $ENVIRONMENT"
echo "=================================="

case $ENVIRONMENT in
  "dev")
    echo "Expected Security Profile:"
    echo "✅ Shell access: Available (sh/busybox)"
    echo "✅ Package manager: Available (apk)"
    echo "✅ Debug tools: Available"
    echo "⚠️  Security level: Moderate (development debugging enabled)"
    ;;
  "uat"|"prod")
    echo "Expected Security Profile:"
    echo "✅ Shell access: Minimal (busybox only)"
    echo "❌ Package manager: Not available"
    echo "❌ Debug tools: Minimal"
    echo "🔒 Security level: High (distroless with minimal debug)"
    ;;
esac

echo ""
echo "🔍 Verification complete!"
echo "💡 Use 'aws ecs execute-command' to manually test container access"

# Cleanup
rm -f /tmp/shell-test.sh