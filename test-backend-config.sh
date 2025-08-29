#!/bin/bash
# ============================================================================
# BACKEND CONFIGURATION TEST SCRIPT
# ============================================================================
# This script validates the secure backend configuration setup where:
# - Backend configs are stored in AWS Parameter Store (encrypted)
# - No sensitive data is stored in the GitHub repository
# - Terraform fetches backend config at runtime from Parameter Store
# 
# Tests performed:
# 1. Verify Parameter Store entries exist
# 2. Validate backend config format (proper HCL syntax)
# 3. Test terraform init with external backend config
# ============================================================================

echo "🧪 Testing backend configuration setup..."

# Test 1: Check if Parameter Store entries exist
echo "1. Checking Parameter Store entries..."
if aws ssm get-parameter --name "/terraform/backend/shopmate" --with-decryption >/dev/null 2>&1; then
    echo "✅ Main backend config exists"
else
    echo "❌ Main backend config missing - run bootstrap-oidc.sh first"
    exit 1
fi

if aws ssm get-parameter --name "/terraform/backend/shopmate-shared" --with-decryption >/dev/null 2>&1; then
    echo "✅ Shared backend config exists"
else
    echo "❌ Shared backend config missing - run bootstrap-oidc.sh first"
    exit 1
fi

# Test 2: Validate backend config format
echo "2. Validating backend config format..."
aws ssm get-parameter --name "/terraform/backend/shopmate" --with-decryption --query "Parameter.Value" --output text > test-backend.hcl

if grep -q 'bucket.*=.*"sctp-ce10-tfstate"' test-backend.hcl && \
   grep -q 'workspace_key_prefix.*=.*"shopmate/env"' test-backend.hcl && \
   grep -q 'dynamodb_table.*=.*"terraform-state-locks"' test-backend.hcl; then
    echo "✅ Main backend config format is correct"
else
    echo "❌ Main backend config format is invalid"
    cat test-backend.hcl
    exit 1
fi

# Test 3: Test terraform init with backend config
echo "3. Testing terraform init with backend config..."
cd infra/terraform
if terraform init -reconfigure -backend-config=../../test-backend.hcl >/dev/null 2>&1; then
    echo "✅ Terraform init with backend config successful"
else
    echo "❌ Terraform init with backend config failed"
    exit 1
fi

# Cleanup
rm -f ../../test-backend.hcl
rm -rf .terraform .terraform.lock.hcl

echo "✅ All backend configuration tests passed!"