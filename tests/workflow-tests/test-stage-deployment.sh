#!/bin/bash

# Test script for stage deployment workflow
echo "🧪 Testing Stage Deployment Workflow"
echo "===================================="

# Ensure we're on dev branch
echo "1. Switching to dev branch..."
git checkout dev
git pull

echo "2. Creating PR from dev to stage..."
echo "   Go to GitHub and create PR: dev → stage"
echo "   This should trigger the stage workflow when merged"

echo ""
echo "✅ Test setup complete!"
echo "📋 Next steps:"
echo "   1. Go to GitHub and create PR: dev → stage"
echo "   2. Merge PR (requires manual approval if environment is set up)"
echo "   3. Check Actions tab for workflow execution"
echo "   4. Verify deployment to staging environment"

echo ""
echo "🔍 What to verify:"
echo "   - Terraform validation passes"
echo "   - Docker image builds and pushes to ECR"
echo "   - ECS service updates with new image"
echo "   - Application is accessible via load balancer"