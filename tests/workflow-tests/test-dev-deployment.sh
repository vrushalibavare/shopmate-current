#!/bin/bash

# Test script for dev deployment workflow
echo "🧪 Testing Dev Deployment Workflow"
echo "=================================="

# Create a test feature branch
echo "1. Creating test feature branch..."
git checkout dev
git pull
git checkout -b feature/test-deployment-$(date +%s)

# Make a small change
echo "2. Making test change..."
echo "// Test deployment $(date)" >> public/js/main.js

# Commit and push
echo "3. Committing test change..."
git add .
git commit -m "test: trigger dev deployment workflow"
git push --set-upstream origin $(git branch --show-current)

echo "4. Creating PR to dev branch..."
echo "   Go to GitHub and create PR: $(git branch --show-current) → dev"
echo "   This should trigger the dev workflow when merged"

echo ""
echo "✅ Test setup complete!"
echo "📋 Next steps:"
echo "   1. Go to GitHub and create PR"
echo "   2. Merge PR to trigger dev deployment"
echo "   3. Check Actions tab for workflow execution"