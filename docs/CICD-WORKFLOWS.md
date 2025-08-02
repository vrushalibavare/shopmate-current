# CI/CD Workflows Documentation

## Overview

The ShopMate application uses GitHub Actions for automated CI/CD with a multi-environment deployment strategy. The workflows are optimized for efficiency by building Docker images once in development and promoting the same tested artifacts through staging to production.

## Architecture

### State Management
- **Terraform Backend**: S3 bucket (`sctp-ce10-tfstate`) for remote state storage
- **Environment Isolation**: Separate state files for each environment
  - Dev: `shopmate/dev/terraform.tfstate`
  - UAT: `shopmate/uat/terraform.tfstate`
  - Prod: `shopmate/prod/terraform.tfstate`

### Container Registry
- **Shared ECR Repository**: `shopmate` repository used across all environments
- **Image Promotion**: Same Docker image promoted from dev → stage → prod
- **Automatic Cleanup**: ECR lifecycle policy manages old images

## Workflows

### 1. Development Deployment (`dev.yml`)

**Trigger**: Push to `dev` branch

**Process**:
1. **Validate**: Format check, init, validate, plan
2. **Deploy**: 
   - Deploy infrastructure with Terraform
   - Build and push Docker image (commit SHA + latest tags)
   - Deploy to ECS

**Key Features**:
- Builds Docker images for the first time
- Creates both commit-specific and `latest` tags
- Full infrastructure deployment

### 2. Staging Deployment (`stage.yml`)

**Trigger**: PR from `dev` to `stage` (when merged)

**Process**:
1. **Validate**: Format check, init, validate, plan
2. **Deploy**:
   - Get source commit SHA from dev branch
   - Deploy infrastructure (reuses existing Docker image)
   - No Docker build step (promotes dev image)

**Key Features**:
- **Image Promotion**: Reuses Docker image built in dev
- **Faster Deployment**: No rebuild time
- **True Promotion**: Same tested artifact from dev

### 3. Production Deployment (`production.yml`)

**Trigger**: PR from `stage` to `production` (when merged)

**Process**:
1. **Validate**: Format check, init, validate, plan
2. **Deploy**:
   - Get source commit SHA from dev branch (original source)
   - Deploy infrastructure (reuses existing Docker image)
   - No Docker build step (promotes dev image)

**Key Features**:
- **Image Promotion**: Reuses Docker image built in dev
- **Production Environment**: GitHub environment protection
- **Consistent Artifacts**: Same image tested in dev and stage

### 4. Infrastructure Destroy (`destroy.yml`)

**Trigger**: Manual dispatch with environment selection

**Process**:
1. **Safety Check**: Requires typing "DESTROY" to confirm
2. **Selective Destroy**: Destroys environment-specific resources
3. **ECR Preservation**: ECR repository and images remain intact

**Key Features**:
- **Manual Only**: Prevents accidental destruction
- **Environment Selection**: Choose dev/uat/prod
- **Shared Resource Protection**: ECR survives environment destruction
- **Graceful Failure Handling**: Continues even if some resources can't be destroyed

### 5. ECR Cleanup (`cleanup-ecr.yml`)

**Trigger**: Manual dispatch with action selection

**Actions**:
- **cleanup-images**: Remove old images (keep latest 5)
- **delete-repository**: Complete ECR deletion

**Key Features**:
- **Manual Control**: Separate workflow for ECR management
- **Safety Confirmation**: Requires typing "CLEANUP"
- **Flexible Options**: Image cleanup or complete removal

## Workflow Optimizations

### Image Promotion Strategy
```
Dev Branch Push → Build Image → Push to ECR
                     ↓
Stage Deployment → Reuse Dev Image (no rebuild)
                     ↓
Prod Deployment → Reuse Dev Image (no rebuild)
```

### Benefits
- **Faster Deployments**: No rebuild time for stage/prod
- **Consistent Artifacts**: Same tested image across environments
- **Cost Efficiency**: Reduced CI/CD minutes
- **Better Traceability**: Clear image lineage from dev to prod

## Environment Configuration

### Development
- **Instance Count**: 1
- **Domain**: `shopmate.dev.sctp-sandbox.com`
- **Auto-scaling**: 1-5 instances

### Staging (UAT)
- **Instance Count**: 2
- **Domain**: `shopmate.uat.sctp-sandbox.com`
- **Auto-scaling**: 2-5 instances

### Production
- **Instance Count**: 3
- **Domain**: `shopmate.prod.sctp-sandbox.com`
- **Auto-scaling**: 3-10 instances
- **GitHub Environment**: Production protection enabled

## Required Secrets

Configure these in GitHub repository settings:

```
AWS_ACCESS_KEY_ID     - AWS access key for deployments
AWS_SECRET_ACCESS_KEY - AWS secret key for deployments
```

## Usage Examples

### Deploy to Development
```bash
git checkout dev
git add .
git commit -m "Feature: Add new functionality"
git push origin dev
# Workflow automatically triggers
```

### Promote to Staging
```bash
# Create PR from dev to stage
gh pr create --base stage --head dev --title "Release v1.2.0"
# Merge PR to trigger staging deployment
```

### Promote to Production
```bash
# Create PR from stage to production
gh pr create --base production --head stage --title "Production Release v1.2.0"
# Merge PR to trigger production deployment
```

### Destroy Environment
1. Go to GitHub Actions → "Destroy Infrastructure"
2. Click "Run workflow"
3. Select environment (dev/uat/prod)
4. Type "DESTROY" in confirmation
5. Click "Run workflow"

### Cleanup ECR
1. Go to GitHub Actions → "Cleanup ECR Repository"
2. Click "Run workflow"
3. Select action (cleanup-images/delete-repository)
4. Type "CLEANUP" in confirmation
5. Click "Run workflow"

## Best Practices

### Development
- Test locally before pushing to dev
- Use feature branches for development
- Ensure Docker builds succeed locally

### Deployment
- Always deploy to dev first
- Test thoroughly in staging before production
- Use descriptive commit messages for traceability

### Maintenance
- Regularly clean up old ECR images
- Monitor CloudWatch costs and logs
- Review and update IAM permissions periodically