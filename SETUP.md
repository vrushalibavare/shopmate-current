# ShopMate Setup Guide

Complete setup guide for the ShopMate e-commerce application with secure backend configuration.

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform (v1.0+)
- Node.js (v14+)
- Git

### 1. Initial Setup

#### Create S3 Bucket for Terraform State
```bash
# Create a new S3 bucket for secure state storage
# Replace 'your-unique-bucket-name' with your chosen bucket name
aws s3 mb s3://your-unique-bucket-name --region ap-southeast-1
```

#### Update Bootstrap Script
Edit `bootstrap-infrastructure.sh` and replace `vrush-tfstate-bucket` with your bucket name:
```bash
# Line 18 and 27: Update bucket name
bucket = "your-unique-bucket-name"
```

### 2. Bootstrap Infrastructure

Run the bootstrap script to set up shared infrastructure:
```bash
./bootstrap-infrastructure.sh
```

This script will:
- ✅ Create secure backend configurations in Parameter Store
- ✅ Deploy ECR repository
- ✅ Create GitHub OIDC role
- ✅ Set up DynamoDB state locking table

### 3. Configure GitHub Secrets

Add the GitHub Actions role ARN to your repository secrets:

1. Go to **GitHub Repository** → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. **Name**: `AWS_GITHUB_ACTIONS_ROLE_ARN`
4. **Value**: Copy the ARN from bootstrap script output
5. Click **Add secret**

### 4. Test Deployment

Create a test deployment:
```bash
# Run the dev workflow test
./testing/tests/workflow-tests/test-dev-deployment.sh
```

## 🏗️ Architecture Overview

### Secure Backend Configuration
- **Backend configs stored in AWS Parameter Store** (encrypted)
- **No sensitive data in GitHub repository**
- **Workflows fetch configs at runtime**
- **IAM-controlled access**

### Infrastructure Components
- **ECR Repository**: Container image storage
- **GitHub OIDC Role**: Secure CI/CD authentication
- **DynamoDB Table**: Terraform state locking
- **Parameter Store**: Encrypted backend configurations

### Deployment Flow
1. **Bootstrap** (one-time): Sets up shared infrastructure
2. **Dev Workflow**: Builds images, deploys to dev environment
3. **Stage Workflow**: Promotes to UAT using prod images
4. **Production Workflow**: Deploys to production

## 📁 Key Files

| File | Purpose |
|------|---------|
| `bootstrap-infrastructure.sh` | One-time setup script |
| `.github/workflows/dev.yml` | Development deployment |
| `.github/workflows/stage.yml` | Staging deployment |
| `.github/workflows/production.yml` | Production deployment |
| `infra/terraform/shared/` | Shared infrastructure code |
| `infra/terraform/` | Environment-specific infrastructure |

## 🔧 Environment Configuration

### Development
- **Trigger**: PR merge to `dev` branch
- **Image**: `dev-latest` (with debug tools)
- **URL**: `shopmate.dev.sctp-sandbox.com`

### Staging (UAT)
- **Trigger**: PR merge from `dev` to `stage` branch
- **Image**: `prod-latest` (secure distroless)
- **URL**: `shopmate.uat.sctp-sandbox.com`

### Production
- **Trigger**: PR merge from `stage` to `production` branch
- **Image**: `prod-latest` (secure distroless)
- **URL**: `shopmate.sctp-sandbox.com`

## 🛠️ Troubleshooting

### Common Issues

**Bootstrap fails with "Parameter not found"**
- Ensure AWS CLI is configured with proper permissions
- Check that you're in the correct AWS region

**Workflow fails with "Unable to locate credentials"**
- Verify GitHub secret `AWS_GITHUB_ACTIONS_ROLE_ARN` is set correctly
- Check OIDC role permissions in AWS IAM

**Terraform state lock errors**
- DynamoDB table should be created by bootstrap
- If issues persist, check table exists in AWS console

### Debug Commands
```bash
# Check Parameter Store entries
aws ssm get-parameter --name "/terraform/backend/shopmate" --with-decryption

# Verify OIDC role
aws iam get-role --role-name shopmate-github-actions-role

# Check DynamoDB table
aws dynamodb describe-table --table-name terraform-state-locks
```

## 📚 Additional Resources

- [Deployment Guide](docs/DEPLOYMENT.md)
- [CI/CD Guide](docs/CICD.md)
- [Testing Guide](docs/TESTING.md)

---

**Need help?** Check the troubleshooting section or review the architecture documentation.