# Workflow Test Scripts

This directory contains test scripts to validate your CI/CD workflow operations.

## Scripts Overview

### 🧪 Deployment Tests
- **`test-dev-deployment.sh`** - Creates test feature and guides through dev deployment
- **`test-stage-deployment.sh`** - Guides through stage deployment process  
- **`test-production-deployment.sh`** - Guides through production deployment process

### 🔧 Validation Scripts
- **`validate-terraform.sh`** - Validates all Terraform configurations locally
- **`check-workflow-syntax.sh`** - Validates GitHub workflow YAML syntax
- **`test-docker-build.sh`** - Tests Docker build process locally

## Usage

### Make scripts executable:
```bash
chmod +x tests/workflow-tests/*.sh
```

### Run validation checks:
```bash
# Check Terraform syntax
./tests/workflow-tests/validate-terraform.sh

# Check workflow YAML syntax  
./tests/workflow-tests/check-workflow-syntax.sh

# Test Docker build
./tests/workflow-tests/test-docker-build.sh
```

### Test deployments:
```bash
# Test dev deployment
./tests/workflow-tests/test-dev-deployment.sh

# Test stage deployment (after dev is working)
./tests/workflow-tests/test-stage-deployment.sh

# Test production deployment (after stage is working)
./tests/workflow-tests/test-production-deployment.sh
```

## Prerequisites

### For workflow syntax checking:
```bash
pip install yamllint
```

### For Terraform validation:
- Terraform installed locally
- AWS credentials configured

### For Docker testing:
- Docker installed and running
- Sufficient disk space for image builds

## Testing Flow

1. **Pre-deployment validation:**
   ```bash
   ./tests/workflow-tests/validate-terraform.sh
   ./tests/workflow-tests/check-workflow-syntax.sh
   ./tests/workflow-tests/test-docker-build.sh
   ```

2. **Test deployment flow:**
   ```bash
   # Test each environment in order
   ./tests/workflow-tests/test-dev-deployment.sh
   ./tests/workflow-tests/test-stage-deployment.sh
   ./tests/workflow-tests/test-production-deployment.sh
   ```

## What Each Test Validates

### Dev Deployment Test
- ✅ Feature branch creation
- ✅ PR creation process
- ✅ Workflow trigger on merge
- ✅ Terraform validation
- ✅ Docker build and push
- ✅ ECS deployment

### Stage Deployment Test  
- ✅ PR from dev to stage
- ✅ Branch restriction enforcement
- ✅ Manual approval process (if configured)
- ✅ UAT environment deployment

### Production Deployment Test
- ✅ PR from stage to production
- ✅ Branch restriction enforcement  
- ✅ Production approval process
- ✅ Production environment deployment
- ✅ Scaling configuration (3 instances)

## Troubleshooting

### Common Issues:
1. **Terraform validation fails** - Check AWS credentials and permissions
2. **Docker build fails** - Check Dockerfile syntax and dependencies
3. **Workflow syntax errors** - Run yamllint for detailed error messages
4. **Permission denied** - Make scripts executable with `chmod +x`

### Logs and Monitoring:
- Check GitHub Actions tab for workflow execution logs
- Monitor AWS CloudWatch for application logs
- Use AWS Console to verify ECS service status