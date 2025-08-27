#!/bin/bash
# Destroy shared infrastructure (OIDC, ECR, State Locking)
# WARNING: This will break GitHub Actions workflows until re-bootstrapped

echo "⚠️  WARNING: This will destroy shared infrastructure!"
echo "   - OIDC role (breaks GitHub Actions)"
echo "   - ECR repository (loses all images)"
echo "   - State locking table"
echo ""
read -p "Are you sure you want to destroy shared infrastructure? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo "❌ Destruction cancelled"
  exit 1
fi

echo "💥 Destroying shared infrastructure..."
cd infra/terraform/shared
terraform destroy -auto-approve

echo "✅ Shared infrastructure destroyed"
echo "🔄 To restore: Run ./bootstrap-oidc.sh and update GitHub secrets"