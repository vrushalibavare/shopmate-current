#!/bin/bash

# Script to check GitHub workflow YAML syntax
echo "📝 Checking GitHub Workflow Syntax"
echo "=================================="

WORKFLOW_DIR=".github/workflows"

if ! command -v yamllint &> /dev/null; then
    echo "⚠️  yamllint not found. Installing..."
    if command -v pip3 &> /dev/null; then
        pip3 install yamllint
    else
        echo "❌ pip3 not found. Please install yamllint manually:"
        echo "   pip install yamllint"
        exit 1
    fi
fi

echo ""
for workflow in "$WORKFLOW_DIR"/*.yml; do
    filename=$(basename "$workflow")
    echo "🔍 Checking $filename..."
    
    if yamllint "$workflow" > /dev/null 2>&1; then
        echo "  ✅ Syntax valid"
    else
        echo "  ❌ Syntax errors found:"
        yamllint "$workflow"
    fi
done

echo ""
echo "🏁 Workflow syntax check complete!"