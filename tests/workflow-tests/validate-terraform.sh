#!/bin/bash

# Script to validate Terraform configurations locally
echo "🔧 Validating Terraform Configurations"
echo "======================================"

ENVIRONMENTS=("dev" "uat" "prod")

for env in "${ENVIRONMENTS[@]}"; do
    echo ""
    echo "📁 Validating $env environment..."
    cd "terraform/environments/$env"
    
    echo "  - Checking format..."
    if terraform fmt -check; then
        echo "    ✅ Format check passed"
    else
        echo "    ❌ Format check failed"
        terraform fmt -diff
    fi
    
    echo "  - Initializing..."
    if terraform init > /dev/null 2>&1; then
        echo "    ✅ Init successful"
    else
        echo "    ❌ Init failed"
    fi
    
    echo "  - Validating..."
    if terraform validate > /dev/null 2>&1; then
        echo "    ✅ Validation passed"
    else
        echo "    ❌ Validation failed"
        terraform validate
    fi
    
    cd - > /dev/null
done

echo ""
echo "🏁 Terraform validation complete!"