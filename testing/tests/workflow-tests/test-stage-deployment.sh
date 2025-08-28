#!/bin/bash

# Test stage deployment workflow
echo "🚀 Testing Stage Deployment"
echo "=========================="

echo "1. Checking current branch..."
CURRENT_BRANCH=$(git branch --show-current)
echo "   Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "dev" ]; then
    echo "   ⚠️  Please switch to dev branch first"
    echo "   Run: git checkout dev"
    exit 1
fi

echo "2. Ensuring dev is up to date..."
git pull origin dev

echo "3. Creating test change to trigger workflow..."
echo "UAT deployment test $(date)" > uat-test-$(date +%s).tmp
git add .
git commit -m "test: trigger UAT deployment workflow"
git push origin dev
echo "   ✅ Test change created and pushed"

echo "4. Creating PR from dev to stage..."
echo "   This will trigger the stage deployment workflow"
echo "   
   Steps to complete manually:
   1. Go to GitHub repository
   2. Create Pull Request: dev → stage  
   3. Add title: 'Deploy to staging'
   4. Merge the PR
   5. Check GitHub Actions for workflow execution
   "

echo "5. Monitoring deployment..."
echo "   Check these after PR merge:"
echo "   - GitHub Actions: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
echo "   - AWS ECS Console: https://console.aws.amazon.com/ecs/home?region=ap-southeast-1#/clusters"
echo "   - Application URL will be shown in workflow output"

echo ""
echo "✅ Stage deployment test setup complete!"
echo "📋 Next steps:"
echo "   1. Create and merge PR from dev to stage"
echo "   2. Monitor GitHub Actions workflow"
echo "   3. Verify staging environment in AWS Console"