# CI/CD Workflows Documentation

## Overview

The ShopMate application uses GitHub Actions for automated CI/CD with a multi-environment deployment strategy and selective service deployment. The workflows are optimized for efficiency by building Docker images once in development and promoting the same tested artifacts through staging to production.

## Architecture

### State Management
- **Terraform Backend**: S3 bucket (`sctp-ce10-tfstate`) for remote state storage
- **Environment Isolation**: Separate state files for each environment
  - Dev: `shopmate/dev/terraform.tfstate`
  - UAT: `shopmate/uat/terraform.tfstate`
  - Prod: `shopmate/prod/terraform.tfstate`

### Container Registry
- **Shared ECR Repository**: `shopmate` repository used across all environments
- **Image Tagging Strategy**: SHA-based tags for immutable deployments
  - Main app: `shopmate:abc123def456` (commit SHA)
  - Prometheus: `shopmate:prometheus` (static tag)
  - Grafana: Uses official `grafana/grafana:latest`
- **Image Promotion**: Same Docker image promoted from dev → stage → prod
- **Automatic Cleanup**: ECR lifecycle policy manages old images

### Service Architecture
- **Main Application**: Node.js app with DynamoDB integration
- **Monitoring Stack**: Prometheus + Grafana with ALB path-based routing
- **Load Balancer**: Single ALB with multiple listener rules
  - `/` → ShopMate app
  - `/prometheus/*` → Prometheus
  - `/grafana/*` → Grafana

## Workflows

### 1. Main Application Deployment (`dev.yml`)

**Trigger**: PR to `dev` branch (when merged)
**Exclusions**: Ignores Prometheus and monitoring file changes

**Process**:
1. **Validate**: Format check, init, validate, plan
2. **Deploy Infrastructure**: Apply Terraform with SHA-based image tag
3. **Build & Push**: Build Docker image with commit SHA tag
4. **Deploy**: ECS service uses specific SHA tag (not `:latest`)

**Key Features**:
- **SHA-based Tagging**: `TF_VAR_image_tag=${{ github.sha }}`
- **Immutable Deployments**: Each commit gets unique image
- **Path Exclusions**: Skips when only monitoring configs change
- **Infrastructure First**: Terraform runs before Docker build

### 2. Prometheus Monitoring Deployment (`prometheus-deploy.yml`)

**Trigger**: Push to `dev` branch with monitoring file changes
**Includes**: `terraform/prometheus.yml`, `Dockerfile.prometheus`, `monitoring/**`

**Process**:
1. **Build Custom Image**: Prometheus with custom configuration
2. **Push to ECR**: Tagged as `shopmate:prometheus`
3. **Force Deployment**: ECS service restart to pick up new image

**Key Features**:
- **Selective Deployment**: Only runs when monitoring configs change
- **Custom Configuration**: Baked-in prometheus.yml
- **Dev Environment Only**: Manual promotion to stage/prod
- **Fast Deployment**: No infrastructure changes, just service restart

### 3. Staging Deployment (`stage.yml`)

**Trigger**: PR from `dev` to `stage` (when merged)

**Process**:
1. **Validate**: Format check, init, validate, plan
2. **Get Source SHA**: Extract commit SHA from dev branch
3. **Deploy**: Terraform with `TF_VAR_image_tag` from dev
4. **Promote**: Same tested image from dev environment

**Key Features**:
- **Image Promotion**: Reuses Docker image built in dev
- **SHA Traceability**: Uses original commit SHA from dev
- **No Build Step**: Faster deployment, consistent artifacts
- **Branch Validation**: Only accepts PRs from dev branch

### 4. Production Deployment (`production.yml`)

**Trigger**: PR from `stage` to `production` (when merged)

**Process**:
1. **Validate**: Format check, init, validate, plan
2. **Get Source SHA**: Extract original commit SHA from dev branch
3. **Deploy**: Terraform with same SHA tag used in dev/stage
4. **Production Environment**: GitHub environment protection

**Key Features**:
- **Image Promotion**: Same image tested in dev and stage
- **Production Safeguards**: GitHub environment protection
- **Audit Trail**: Clear lineage from dev commit to production
- **Branch Validation**: Only accepts PRs from stage branch

### 5. Infrastructure Destroy (`destroy.yml`)

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

### 6. ECR Cleanup (`cleanup-ecr.yml`)

**Trigger**: Manual dispatch with action selection

**Actions**:
- **cleanup-images**: Remove old images (keep latest 5)
- **delete-repository**: Complete ECR deletion

**Key Features**:
- **Manual Control**: Separate workflow for ECR management
- **Safety Confirmation**: Requires typing "CLEANUP"
- **Flexible Options**: Image cleanup or complete removal

## Workflow Decision Tree

```
Code Change
├── App Code Changed?
│   ├── Yes → Main App Workflow (dev.yml)
│   │   ├── Build SHA-tagged image
│   │   ├── Deploy to dev
│   │   └── Ready for promotion
│   └── No → Check monitoring files
├── Monitoring Config Changed?
│   ├── Yes → Prometheus Workflow (prometheus-deploy.yml)
│   │   ├── Build custom Prometheus image
│   │   ├── Deploy to dev only
│   │   └── Manual promotion needed
│   └── No → No deployment triggered
└── PR Between Branches?
    ├── dev → stage → Stage Workflow (stage.yml)
    ├── stage → prod → Production Workflow (production.yml)
    └── Promote existing SHA-tagged images
```

## Workflow Flow Diagram

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Code Change   │    │  Monitoring      │    │   Manual        │
│   (App Files)   │    │  Config Change   │    │   Actions       │
└─────────┬───────┘    └─────────┬────────┘    └─────────┬───────┘
          │                      │                       │
          ▼                      ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Main App        │    │ Prometheus       │    │ Destroy/Cleanup │
│ Workflow        │    │ Workflow         │    │ Workflows       │
│ (dev.yml)       │    │ (prometheus-     │    │                 │
│                 │    │  deploy.yml)     │    │                 │
└─────────┬───────┘    └─────────┬────────┘    └─────────────────┘
          │                      │
          ▼                      ▼
┌─────────────────┐    ┌──────────────────┐
│ Build SHA Image │    │ Build Prometheus │
│ shopmate:abc123 │    │ shopmate:        │
│                 │    │ prometheus       │
└─────────┬───────┘    └─────────┬────────┘
          │                      │
          ▼                      ▼
┌─────────────────┐    ┌──────────────────┐
│ Deploy to Dev   │    │ Deploy to Dev    │
│ ECS Service     │    │ Prometheus Only  │
└─────────┬───────┘    └──────────────────┘
          │
          ▼
┌─────────────────┐
│ Create PR       │
│ dev → stage     │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ Stage Workflow  │
│ (Promote SHA)   │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ Create PR       │
│ stage → prod    │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ Prod Workflow   │
│ (Promote SHA)   │
└─────────────────┘
```

## Image Tagging Strategy

### SHA-based Tagging (Main App)
```
Commit: abc123def456
├── Dev Build: shopmate:abc123def456
├── Stage Deploy: shopmate:abc123def456 (reuse)
└── Prod Deploy: shopmate:abc123def456 (reuse)
```

### Static Tagging (Monitoring)
```
Prometheus Config Change
├── Build: shopmate:prometheus
├── Deploy to Dev: shopmate:prometheus
└── Manual Promotion: Copy to stage/prod when ready
```

### Terraform Variable Mapping
```
Environment Variable → Terraform Variable
TF_VAR_image_tag=abc123 → var.image_tag
├── Manual Run: Uses default "latest"
└── CI/CD Run: Uses SHA or "prometheus"
```

## Benefits

### Selective Deployment
- **Faster Builds**: Only build what changed
- **Independent Services**: App and monitoring deploy separately
- **Reduced CI/CD Time**: Skip unnecessary builds
- **Clear Separation**: Monitoring changes don't affect app

### SHA-based Immutability
- **Audit Trail**: Know exactly which code is running
- **Rollback Capability**: Deploy any previous SHA
- **Consistent Artifacts**: Same image across all environments
- **No Latest Tag Issues**: Explicit versioning

### Image Promotion
- **Faster Deployments**: No rebuild time for stage/prod
- **Tested Artifacts**: Same image tested in dev
- **Cost Efficiency**: Reduced build minutes
- **Better Reliability**: Eliminate build-time differences

## Environment Configuration

### Development
- **Instance Count**: 1
- **Domain**: `shopmate.dev.sctp-sandbox.com`
- **Auto-scaling**: 1-5 instances
- **Image Strategy**: SHA-tagged builds

### Staging (UAT)
- **Instance Count**: 2
- **Domain**: `shopmate.uat.sctp-sandbox.com`
- **Auto-scaling**: 2-5 instances
- **Image Strategy**: Promoted from dev

### Production
- **Instance Count**: 3
- **Domain**: `shopmate.prod.sctp-sandbox.com`
- **Auto-scaling**: 3-10 instances
- **Image Strategy**: Promoted from stage
- **GitHub Environment**: Production protection enabled

## Required Secrets

Configure these in GitHub repository settings:

```
AWS_ACCESS_KEY_ID     - AWS access key for deployments
AWS_SECRET_ACCESS_KEY - AWS secret key for deployments
```

## Usage Examples

### Deploy Application Changes
```bash
# Make app code changes
git checkout dev
git add app.js controllers/ models/
git commit -m "Feature: Add new functionality"
git push origin dev
# Main app workflow triggers automatically
```

### Deploy Monitoring Changes
```bash
# Make monitoring config changes
git checkout dev
git add terraform/prometheus.yml
git commit -m "Update Prometheus scrape config"
git push origin dev
# Prometheus workflow triggers automatically
```

### Promote to Staging
```bash
# Create PR from dev to stage
gh pr create --base stage --head dev --title "Release v1.2.0"
# Merge PR to trigger staging deployment with same SHA
```

### Promote to Production
```bash
# Create PR from stage to production
gh pr create --base production --head stage --title "Production Release v1.2.0"
# Merge PR to trigger production deployment with same SHA
```

### Manual Terraform Deployment
```bash
# Uses default "latest" tag
cd terraform/environments/dev
terraform apply

# Use specific SHA tag
export TF_VAR_image_tag=abc123def456
terraform apply
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
- Separate app and monitoring changes when possible
- Ensure Docker builds succeed locally

### Deployment
- Always deploy to dev first
- Test thoroughly in staging before production
- Use descriptive commit messages for SHA traceability
- Monitor both app and Prometheus deployments

### Monitoring
- Test Prometheus config changes in dev first
- Manually promote monitoring changes to stage/prod
- Keep monitoring configs environment-agnostic when possible

### Maintenance
- Regularly clean up old ECR images
- Monitor CloudWatch costs and logs
- Review and update IAM permissions periodically
- Track SHA deployment history for rollback planning

## Troubleshooting

### Common Scenarios

**App code changed but Prometheus workflow triggered:**
- Check if monitoring files were also modified
- Both workflows can run simultaneously (harmless)

**Stage deployment failed with "image not found":**
- Ensure dev workflow completed successfully
- Check ECR for SHA-tagged image
- Verify commit SHA extraction in stage workflow

**Prometheus changes not reflected:**
- Confirm Dockerfile.prometheus exists
- Check if prometheus.yml is in correct path
- Verify ECS service restart completed

**Manual Terraform uses wrong image:**
- Set `TF_VAR_image_tag` environment variable
- Or update `terraform/variables.tf` default value

### Monitoring Deployment Status

```bash
# Check ECS service status
aws ecs describe-services --cluster shopmate-dev --services shopmate-service-dev

# Check running tasks
aws ecs list-tasks --cluster shopmate-dev --service-name shopmate-service-dev

# Check ECR images
aws ecr describe-images --repository-name shopmate --region ap-southeast-1
```