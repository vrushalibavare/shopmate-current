#!/bin/bash

# Test script for production deployment workflow
echo "🧪 Testing Production Deployment Workflow"
echo "========================================="

# Ensure we're on stage branch
echo "1. Switching to stage branch..."
git checkout stage
git pull

echo "2. Creating PR from stage to production..."
echo "   Go to GitHub and create PR: stage → production"
echo "   This should trigger the production workflow when merged"

echo ""
echo "✅ Test setup complete!"
echo "📋 Next steps:"
echo "   1. Go to GitHub and create PR: stage → production"
echo "   2. Merge PR (requires manual approval for production environment)"
echo "   3. Check Actions tab for workflow execution"
echo "   4. Verify deployment to production environment"

echo ""
echo "🔍 What to verify:"
echo "   - Terraform validation passes"
echo "   - Docker image builds and pushes to ECR"
echo "   - ECS service updates with new image"
echo "   - Application is accessible via load balancer"
echo "   - Production environment has correct scaling (3 instances)"

echo ""
echo "⚠️  Production Checklist:"
echo "   - Ensure staging tests passed"
echo "   - Verify no breaking changes"
echo "   - Have rollback plan ready"