# CI/CD Setup Guide - 3-Branch Structure

## Overview
This guide documents the steps to set up a 3-branch CI/CD pipeline for ShopMate application with automatic deployments to AWS ECS Fargate.

## Branch Structure
- `dev` (default) - Development environment, auto-deploy on push
- `stage` - Staging environment, deploy via PR from dev with manual approval
- `production` - Production environment, deploy via PR from stage with manual approval

## Setup Steps

### 1. Initial Repository Setup
```bash
# Clone the repository
git clone <repository-url>
cd shopmate-new-backup

# Check current branch
git branch -a
```

### 2. Create Branch Structure
```bash
# Create and push dev branch
git checkout -b dev
git push --set-upstream origin dev

# Create and push stage branch  
git checkout -b stage
git push --set-upstream origin stage

# Create and push production branch
git checkout -b production
git push --set-upstream origin production

# Return to main branch
git checkout main
```

### 3. Create Workflow Files
Created three workflow files in `.github/workflows/`:

**dev.yml** - Auto-deploy to development
```yaml
name: Deploy to Development
on:
  push:
    branches: [ dev ]
# ... (deployment steps)
```

**stage.yml** - Deploy to staging via PR from dev
```yaml
name: Deploy to Staging
on:
  pull_request:
    branches: [ stage ]
    types: [ closed ]
jobs:
  check-source:
    if: github.event.pull_request.merged == true && github.event.pull_request.head.ref == 'dev'
# ... (deployment steps)
```

**production.yml** - Deploy to production via PR from stage
```yaml
name: Deploy to Production
on:
  pull_request:
    branches: [ production ]
    types: [ closed ]
jobs:
  check-source:
    if: github.event.pull_request.merged == true && github.event.pull_request.head.ref == 'stage'
# ... (deployment steps)
```

### 4. Commit Workflow Files
```bash
# Add and commit workflow files
git add .
git commit -m "Add CI/CD workflow files for dev, stage, and production"
git push
```

### 5. Distribute Workflow Files to All Branches
```bash
# Merge main into dev
git checkout dev
git merge main
git push --set-upstream origin dev

# Merge main into stage
git checkout stage
git merge main
git push --set-upstream origin stage

# Merge main into production
git checkout production
git merge main
git push --set-upstream origin production
```

### 6. Set Dev as Default Branch
**GitHub UI Steps:**
1. Go to repository Settings
2. Click Branches in sidebar
3. Under "Default branch", click switch icon
4. Select `dev` as new default
5. Click Update

### 7. Delete Main Branch
```bash
# Delete main branch from remote and local
git push origin --delete main
git branch -d main
```

## Workflow Features

### Development Workflow
- **Trigger**: Push to `dev` branch
- **Action**: Auto-deploy to development environment
- **Environment**: AWS ECS Fargate (1 instance)

### Staging Workflow
- **Trigger**: Merged PR from `dev` to `stage`
- **Action**: Deploy to staging with manual approval
- **Environment**: AWS ECS Fargate (2 instances)
- **Restriction**: Only accepts PRs from `dev` branch

### Production Workflow
- **Trigger**: Merged PR from `stage` to `production`
- **Action**: Deploy to production with manual approval
- **Environment**: AWS ECS Fargate (3 instances)
- **Restriction**: Only accepts PRs from `stage` branch

## Developer Workflow

### Feature Development
```bash
# Create feature branch from dev
git checkout dev
git pull
git checkout -b feature/new-feature

# Develop feature
# ... make changes ...

# Push feature branch
git add .
git commit -m "Add new feature"
git push --set-upstream origin feature/new-feature

# Create PR to dev branch (via GitHub UI)
# Merge PR → triggers auto-deploy to development
```

### Promotion Flow
```bash
# Promote dev to staging
# Create PR: dev → stage (via GitHub UI)
# Merge PR → triggers staging deployment

# Promote staging to production  
# Create PR: stage → production (via GitHub UI)
# Merge PR → triggers production deployment
```

## Required GitHub Configuration

### 1. GitHub Secrets
Add these secrets in repository Settings > Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 2. GitHub Environments
Create environments in Settings > Environments:
- `staging` (with manual approval)
- `production` (with manual approval)

### 3. Branch Protection Rules
Recommended settings:
- Protect `stage` and `production` branches
- Require PR reviews
- Require status checks to pass

## Architecture
- **Container Registry**: AWS ECR
- **Compute**: AWS ECS Fargate
- **Infrastructure**: Terraform
- **Platform**: Linux/AMD64
- **Regions**: ap-southeast-1

## Monitoring
Each environment includes CloudWatch dashboard with:
- CPU and memory utilization
- Application logs
- Request counts and latency

## File Structure
```
.github/
  workflows/
    dev.yml
    stage.yml
    production.yml
terraform/
  environments/
    dev/
    uat/
    prod/
```

This setup provides a complete CI/CD pipeline with proper environment isolation and approval gates for production deployments.