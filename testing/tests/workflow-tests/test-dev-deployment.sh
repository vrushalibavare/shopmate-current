#!/bin/bash

# Test dev deployment workflow
echo "🚀 Testing Dev Deployment (Entry Point)"
echo "======================================="

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

echo "3. Creating feature branch for test..."
FEATURE_BRANCH="test-dev-workflow-$(date +%s)"
git checkout -b $FEATURE_BRANCH
echo "   ✅ Created feature branch: $FEATURE_BRANCH"

echo "4. Creating test change to trigger workflow..."
TEST_FILE="test-workflow-$(date +%s).tmp"
echo "# Dev Workflow Test $(date)" > $TEST_FILE
echo "Testing dev deployment workflow" >> $TEST_FILE
git add $TEST_FILE
git commit -m "test: trigger dev workflow

- Test dev deployment pipeline
- Test container builds and security scans
- Test infrastructure deployment"
git push origin $FEATURE_BRANCH
echo "   ✅ Test change created and pushed"

echo "5. Creating PR to dev branch..."
echo "   This will trigger the dev deployment workflow when merged"
echo "   
   Steps to complete manually:
   1. Go to GitHub repository
   2. Create Pull Request: $FEATURE_BRANCH → dev  
   3. Add title: 'Test dev workflow deployment'
   4. Merge the PR
   5. Check GitHub Actions for workflow execution
   "

echo "6. What the dev workflow will do..."
echo "   ✅ Validate and test infrastructure code"
echo "   ✅ Build application container images"
echo "   ✅ Run security scans and Node.js audit"
echo "   ✅ Deploy to dev environment"
echo "   ✅ Create images for stage/prod promotion"

echo "7. Monitoring deployment..."
echo "   Check these after PR merge:"
echo "   - GitHub Actions: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
echo "   - AWS ECR: Check for dev-latest and prod-latest images"
echo "   - AWS ECS Console: https://console.aws.amazon.com/ecs/home?region=ap-southeast-1#/clusters"
echo "   - Application URL will be shown in workflow output"

echo ""
echo "✅ Dev deployment test setup complete!"
echo "📋 Next steps:"
echo "   1. Create and merge PR from $FEATURE_BRANCH to dev"
echo "   2. Monitor GitHub Actions workflow"
echo "   3. Verify dev environment and images in AWS"
echo "   4. After success, run stage deployment test"

echo ""
echo "🔗 Feature branch created: $FEATURE_BRANCH"
echo "   Switch back to dev: git checkout dev"