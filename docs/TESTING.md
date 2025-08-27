# Testing Guide

## Prerequisites

1. **Bootstrap Setup**:
   ```bash
   ./bootstrap-oidc.sh
   # Add role ARN to GitHub secrets
   ```

2. **GitHub Configuration**:
   - Secret: `AWS_GITHUB_ACTIONS_ROLE_ARN`
   - Branch protection rules enabled
   - Repository branches: `dev`, `stage`, `production`

## End-to-End Testing

### 1. Development Workflow
```bash
# Create feature branch
git checkout dev && git pull
git checkout -b feature/test-deployment
echo "console.log('Test deployment');" >> app/app.js
git add . && git commit -m "feat: test deployment"
git push origin feature/test-deployment

# Create PR to dev and merge
```

**Expected Results**:
- ✅ Workflow completes successfully
- ✅ Dev environment accessible
- ✅ ECR has `dev-latest` and `prod-latest` images

### 2. UAT Workflow
```bash
# Create PR from dev to stage and merge
```

**Expected Results**:
- ✅ Uses existing `prod-latest` image
- ✅ UAT environment accessible
- ✅ No shell access in containers

### 3. Production Workflow
```bash
# Create PR from stage to production and merge
```

**Expected Results**:
- ✅ Uses existing `prod-latest` image
- ✅ Production environment accessible (3 containers)
- ✅ No shell access in containers

## Verification Commands

### Check Deployments
```bash
# Health checks
curl -k https://shopmate.dev.sctp-sandbox.com/health
curl -k https://shopmate.uat.sctp-sandbox.com/health
curl -k https://shopmate.sctp-sandbox.com/health

# Container counts
aws ecs describe-services --cluster shopmate-dev --services shopmate-service-dev
aws ecs describe-services --cluster shopmate-uat --services shopmate-service-uat
aws ecs describe-services --cluster shopmate-prod --services shopmate-service-prod
```

### Check Images
```bash
# ECR images
aws ecr list-images --repository-name shopmate

# Terraform workspaces
cd infra/terraform
terraform workspace list
terraform workspace select dev && terraform show | grep image_tag
terraform workspace select uat && terraform show | grep image_tag
terraform workspace select prod && terraform show | grep image_tag
```

## Security Testing

### 1. Shell Access Test
```bash
# Should work in dev
aws ecs execute-command --cluster shopmate-dev --task <task-arn> --container shopmate --command "/bin/sh" --interactive

# Should fail in uat/prod (distroless)
aws ecs execute-command --cluster shopmate-uat --task <task-arn> --container shopmate --command "/bin/sh" --interactive
```

### 2. Branch Protection Test
```bash
# Create PR from wrong branch (should be rejected)
git checkout -b feature/wrong-branch
git push origin feature/wrong-branch
# Try to create PR to stage (should only accept from dev)
```

## Load Testing

### Autoscaling Test
```bash
cd infra/scripts
./gentle-autoscaling.sh

# Monitor scaling
./monitor-scaling.sh
```

**Expected Results**:
- ✅ CPU increases above 70%
- ✅ ECS scales containers up
- ✅ Load distributes across containers
- ✅ Sessions work across all containers

## Error Testing

### 1. Missing Image Test
```bash
# Delete prod-latest image
aws ecr batch-delete-image --repository-name shopmate --image-ids imageTag=prod-latest

# Try UAT deployment (should fail with clear message)
```

### 2. Terraform Error Test
```bash
# Introduce syntax error
echo "invalid syntax" >> infra/terraform/main.tf
# Create PR (should fail validation)
```

## Success Criteria

- ✅ **OIDC Authentication**: No access keys used
- ✅ **Workspace Isolation**: Separate state per environment
- ✅ **State Locking**: Prevents concurrent deployments
- ✅ **Secrets Management**: Passwords in Secrets Manager
- ✅ **Resource Tagging**: All resources properly tagged
- ✅ **Zero Downtime**: Production updates without interruption
- ✅ **Security**: Distroless containers in uat/prod
- ✅ **Monitoring**: Grafana/Prometheus accessible
- ✅ **Autoscaling**: Responds to load increases

## Troubleshooting

**Workflow fails**:
- Check GitHub Actions logs
- Verify OIDC role ARN
- Check terraform syntax

**Application not accessible**:
- Check ECS service status
- Verify ALB health checks
- Check security group rules

**Autoscaling not working**:
- Check CloudWatch metrics
- Verify scaling policies
- Check ECS service configuration