#!/bin/bash

# Test production deployment workflow
echo "🚀 Testing Production Deployment"
echo "==============================="

echo "1. Checking current branch..."
CURRENT_BRANCH=$(git branch --show-current)
echo "   Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "stage" ]; then
    echo "   ⚠️  Please switch to stage branch first"
    echo "   Run: git checkout stage"
    exit 1
fi

echo "2. Ensuring stage is up to date..."
git pull origin stage

echo "3. Creating PR from stage to production..."
echo "   This will trigger the production deployment workflow"
echo "   
   Steps to complete manually:
   1. Go to GitHub repository
   2. Create Pull Request: stage → production  
   3. Add title: 'Deploy to production'
   4. Merge the PR (may require approval)
   5. Check GitHub Actions for workflow execution
   "

echo "4. Monitoring deployment..."
echo "   Check these after PR merge:"
echo "   - GitHub Actions: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
echo "   - AWS ECS Console: https://console.aws.amazon.com/ecs/home?region=ap-southeast-1#/clusters"
echo "   - Production URL will be shown in workflow output"

echo ""
echo "⚠️  PRODUCTION DEPLOYMENT CHECKLIST:"
echo "   □ Staging environment tested and verified"
echo "   □ All tests passing"
echo "   □ Stakeholder approval obtained"
echo "   □ Rollback plan prepared"

echo ""
echo "✅ Production deployment test setup complete!"
echo "📋 Next steps:"
echo "   1. Create and merge PR from stage to production"
echo "   2. Monitor GitHub Actions workflow"
echo "   3. Verify production environment in AWS Console"
echo "   4. Perform smoke tests on production"