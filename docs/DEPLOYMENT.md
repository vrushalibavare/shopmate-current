# Deployment Guide

## Initial Setup

### 1. Bootstrap Infrastructure
```bash
# Creates shared resources: ECR, OIDC role, state locking
./bootstrap-oidc.sh
```

### 2. Configure GitHub
1. Copy role ARN from bootstrap output
2. Add GitHub secret: `AWS_GITHUB_ACTIONS_ROLE_ARN`
3. Remove old secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

## Deployment Methods

### GitHub Actions (Recommended)
```bash
# 1. Create feature branch
git checkout -b feature/my-feature
# Make changes, commit, push

# 2. Create PR to dev → triggers dev deployment
# 3. Create PR dev → stage → triggers UAT deployment  
# 4. Create PR stage → production → triggers prod deployment
```

### Manual Deployment
```bash
# Deploy to specific environment
./deploy.sh dev ap-southeast-1
./deploy.sh uat ap-southeast-1
./deploy.sh prod ap-southeast-1
```

## Environment Configuration

Each environment uses its own tfvars file:

**dev**: `terraform.tfvars.dev`
- 1-3 containers, 256 CPU, 512 MB memory
- Uses `dev-latest` image (with shell access)

**uat**: `terraform.tfvars.uat`  
- 2-5 containers, 512 CPU, 1024 MB memory
- Uses `prod-latest` image (distroless, secure)

**prod**: `terraform.tfvars.prod`
- 3-10 containers, 1024 CPU, 2048 MB memory
- Uses `prod-latest` image (distroless, secure)

## Terraform Workspaces

Each environment uses isolated terraform state:
- `env/dev/terraform.tfstate`
- `env/uat/terraform.tfstate`
- `env/prod/terraform.tfstate`

## Deployment Flow

1. **Shared Infrastructure**: ECR, OIDC, State Locking
2. **Environment Infrastructure**: VPC, ECS, ALB, DynamoDB
3. **Container Images**: Build and push to ECR
4. **Service Updates**: Deploy new images with zero downtime

## Monitoring Setup

### Access Monitoring URLs
After deployment, access:
- **Application**: `https://shopmate.[env.]sctp-sandbox.com`
- **Grafana**: `https://shopmate.[env.]sctp-sandbox.com/grafana`
- **Prometheus**: `https://shopmate.[env.]sctp-sandbox.com/prometheus`

### Grafana Login
```bash
# Get Grafana password from AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id shopmate/dev/grafana-admin-password \
  --query SecretString \
  --output text

# Login credentials:
# Username: admin
# Password: (from command above)
```

### Setup Grafana Dashboards
```bash
# 1. Login to Grafana and add data sources:
#    - CloudWatch data source (note the UID from URL)
#    - Prometheus data source: https://shopmate.dev.sctp-sandbox.com/prometheus (note UID)

# 2. Run dashboard setup script
cd infra/grafana-dashboards
./setup-dashboard-env.sh dev

# This automatically creates dashboards with correct resource names
```

## Troubleshooting

### Common Issues

**OIDC authentication fails**:
- Verify role ARN in GitHub secrets
- Check OIDC provider exists

**Terraform validation fails**:
- Run `terraform fmt` to fix formatting
- Check syntax errors in .tf files

**Image not found**:
- Deploy dev environment first (builds prod-latest)
- Check ECR repository has images

**State locking**:
- Wait for other deployments to complete
- Check DynamoDB locks table

### Debug Commands
```bash
# Check terraform workspaces
cd infra/terraform
terraform workspace list

# Check ECR images
aws ecr list-images --repository-name shopmate

# Check ECS services
aws ecs list-services --cluster shopmate-dev

# View terraform state
terraform workspace select dev
terraform show

# Get monitoring URLs
terraform output -raw application_url
terraform output -raw grafana_url
terraform output -raw prometheus_url
```