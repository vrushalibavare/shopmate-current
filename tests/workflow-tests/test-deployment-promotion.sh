#!/bin/bash

# Test deployment promotion: dev → stage → production
echo "🚀 Testing Deployment Promotion Pipeline"
echo "========================================"

TIMESTAMP=$(date +%s)
TEST_BRANCH="test/promotion-$TIMESTAMP"

# Function to check if branch exists on remote
branch_exists() {
    git ls-remote --heads origin "$1" | grep -q "$1"
}

# Function to wait for workflow completion
wait_for_workflow() {
    local branch=$1
    local environment=$2
    echo "⏳ Waiting for $environment deployment to complete..."
    echo "   Check: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
    echo "   Press Enter when $environment workflow completes..."
    read -r
}

echo "1. Creating test branch from dev..."
git checkout dev
git pull
git checkout -b "$TEST_BRANCH"

echo "2. Making test change..."
echo "// Promotion test $(date)" >> public/js/main.js
git add .
git commit -m "test: deployment promotion pipeline"
git push --set-upstream origin "$TEST_BRANCH"

echo "3. Testing dev promotion..."
echo "   Merging to dev branch..."
git checkout dev
git merge "$TEST_BRANCH" --no-ff -m "test: promote to dev"
git push

wait_for_workflow "dev" "development"

echo "4. Testing stage promotion..."
if branch_exists "stage"; then
    git checkout stage
    git pull
    git merge dev --no-ff -m "promote: dev to stage"
    git push
    wait_for_workflow "stage" "staging"
else
    echo "   ⚠️  Stage branch doesn't exist, skipping stage promotion"
fi

echo "5. Testing production promotion..."
if branch_exists "production" || branch_exists "main"; then
    PROD_BRANCH="production"
    if branch_exists "main"; then
        PROD_BRANCH="main"
    fi
    
    git checkout "$PROD_BRANCH"
    git pull
    git merge stage --no-ff -m "promote: stage to production"
    git push
    wait_for_workflow "$PROD_BRANCH" "production"
else
    echo "   ⚠️  Production branch doesn't exist, skipping production promotion"
fi

echo "6. Cleanup..."
git checkout dev
git branch -d "$TEST_BRANCH"
git push origin --delete "$TEST_BRANCH"

echo ""
echo "✅ Deployment promotion test complete!"
echo "📋 Verify in AWS Console:"
echo "   - Check ECS services in each environment"
echo "   - Verify load balancer endpoints"
echo "   - Check CloudWatch logs"