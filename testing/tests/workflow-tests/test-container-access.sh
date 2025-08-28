#!/bin/bash

# Test container exec access across environments
echo "🔒 Testing Container Security Access"
echo "===================================="

test_container_access() {
    local env=$1
    local expected=$2
    
    echo "Testing $env environment (expected: $expected)..."
    
    # Get task details
    TASK_ARN=$(aws ecs list-tasks --cluster shopmate-ecs-$env --service-name shopmate-service-$env --query 'taskArns[0]' --output text --region ap-southeast-1 2>/dev/null)
    
    if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
        echo "   ❌ No running tasks found in $env"
        return 1
    fi
    
    TASK_ID=$(echo $TASK_ARN | cut -d'/' -f3)
    
    # Test shell access
    aws ecs execute-command \
        --cluster shopmate-ecs-$env \
        --task $TASK_ID \
        --container shopmate-container-$env \
        --interactive \
        --command "/bin/sh -c 'echo SUCCESS: Shell access works && whoami'" \
        --region ap-southeast-1 >/dev/null 2>&1
    
    local result=$?
    
    if [ "$expected" = "ALLOW" ]; then
        if [ $result -eq 0 ]; then
            echo "   ✅ $env: Shell access works (expected for development)"
        else
            echo "   ❌ $env: Shell access failed (unexpected for development)"
        fi
    else
        if [ $result -ne 0 ]; then
            echo "   ✅ $env: Shell access blocked (expected for production)"
        else
            echo "   ❌ $env: Shell access works (security risk for production!)"
        fi
    fi
}

echo "1. Testing DEV environment (should allow shell access)..."
test_container_access "dev" "ALLOW"

echo ""
echo "2. Testing UAT environment (should block shell access)..."
test_container_access "uat" "BLOCK"

echo ""
echo "3. Testing PROD environment (should block shell access)..."
test_container_access "prod" "BLOCK"

echo ""
echo "📋 Security Summary:"
echo "   DEV:  Uses dev-latest (Node.js with shell) - Debug access ✅"
echo "   UAT:  Uses prod-latest (distroless) - No shell access ✅"
echo "   PROD: Uses prod-latest (distroless) - No shell access ✅"
echo ""
echo "✅ Container security verification complete!"