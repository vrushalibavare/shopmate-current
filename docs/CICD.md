# CI/CD Guide

## Workflow Overview

**Dev Workflow** (`dev` branch):
- Builds `dev-latest` (with shell) and `prod-latest` (distroless)
- Deploys `dev-latest` to dev environment
- Triggered by PR merge to `dev`

**UAT Workflow** (`stage` branch):
- Uses existing `prod-latest` image
- Deploys to UAT environment
- Triggered by PR merge from `dev` to `stage`

**Production Workflow** (`production` branch):
- Uses existing `prod-latest` image
- Deploys to production environment
- Triggered by PR merge from `stage` to `production`

## Branch Strategy

```
feature/xyz → dev → stage → production
```

**Branch Protection Rules**:
- UAT only accepts PRs from `dev`
- Production only accepts PRs from `stage`
- All PRs require review

## Workflow Steps

### 1. Development
```bash
git checkout dev
git checkout -b feature/my-feature
# Make changes
git push origin feature/my-feature
# Create PR to dev
```

### 2. UAT Promotion
```bash
# After dev testing passes
# Create PR from dev → stage
```

### 3. Production Promotion
```bash
# After UAT testing passes  
# Create PR from stage → production
```

## Security Features

**OIDC Authentication**:
- No AWS access keys in GitHub
- Role-based permissions
- Temporary credentials

**Image Security**:
- Dev: Regular image with shell access
- UAT/Prod: Distroless image (no shell)

**Environment Validation**:
- Each workflow validates correct environment
- Prevents cross-environment deployments

## Monitoring Deployments

**GitHub Actions**:
- View workflow runs in Actions tab
- Check logs for deployment details
- Monitor success/failure status

**AWS Resources**:
- ECS services show running containers
- CloudWatch logs show application output
- ALB health checks verify deployment

## Rollback Strategy

**Automatic**:
- Health checks fail → ECS stops deployment
- Previous containers remain running

**Manual**:
```bash
# Revert to previous commit
git revert <commit-hash>
# Create PR through normal process
```

## Troubleshooting Workflows

**Workflow doesn't trigger**:
- Ensure PR is merged (not closed)
- Check branch names match exactly
- Verify branch protection rules

**OIDC fails**:
- Check `AWS_GITHUB_ACTIONS_ROLE_ARN` secret
- Verify OIDC provider exists
- Check IAM role permissions

**Image validation fails**:
- Deploy dev environment first
- Check ECR has required images
- Verify image tags are correct