# ShopMate E-commerce Application

A cloud-native e-commerce application built with Node.js and Express, designed for AWS ECS Fargate with complete CI/CD automation.

## 🚀 Quick Start

### Prerequisites
- Node.js (v14+)
- AWS CLI configured
- Terraform (v1.0+)

### Local Development
```bash
cd app
npm install
npm run dev
# App runs at http://localhost:3000
```

### AWS Deployment
```bash
# 1. Bootstrap infrastructure (one-time setup)
./bootstrap-oidc.sh

# 2. Add GitHub secret: AWS_GITHUB_ACTIONS_ROLE_ARN (from bootstrap output)

# 3. Deploy via GitHub Actions (recommended)
# Create PR: feature → dev → stage → production

# OR deploy manually
./deploy.sh dev ap-southeast-1
```

## 🏗️ Architecture

**Stateless Design**: Sessions stored in DynamoDB, containers are interchangeable
**Auto-scaling**: ECS Fargate with target tracking
**Multi-environment**: dev/uat/prod with workspace isolation
**Security**: OIDC authentication, distroless containers, secrets management

## 📊 Monitoring

- **Application**: https://your-domain.com
- **Grafana**: https://your-domain.com/grafana
- **Prometheus**: https://your-domain.com/prometheus
- **CloudWatch**: AWS Console dashboards

## 🔧 Key Features

- ✅ **Terraform workspaces** for environment isolation
- ✅ **OIDC authentication** for secure CI/CD
- ✅ **State locking** prevents concurrent deployments
- ✅ **Secrets management** via AWS Secrets Manager
- ✅ **Resource tagging** for cost tracking
- ✅ **Zero-downtime deployments** with health checks
- ✅ **Comprehensive monitoring** with Prometheus/Grafana

## 📁 Project Structure

```
├── app/                    # Application code
├── infra/terraform/        # Infrastructure as Code
│   ├── shared/            # ECR, OIDC, State Locking
│   ├── *.tf              # Environment resources
│   └── terraform.tfvars.* # Environment configurations
├── .github/workflows/      # CI/CD pipelines
├── docs/                   # Detailed documentation
└── *.sh                   # Deployment scripts
```

## 📚 Documentation

- **[Deployment Guide](docs/DEPLOYMENT.md)** - Complete deployment instructions
- **[CI/CD Guide](docs/CICD.md)** - GitHub Actions workflows
- **[Testing Guide](docs/TESTING.md)** - End-to-end testing procedures

## 🛠️ Commands

```bash
# Deploy to environment
./deploy.sh <env> <region>

# Destroy environment (preserves shared resources)
./destroy.sh <env>

# Destroy everything (including OIDC role)
./destroy-shared.sh

# Test autoscaling
cd infra/scripts && ./gentle-autoscaling.sh
```

## 🏷️ Environments

| Environment | URL | Containers | Image |
|-------------|-----|------------|-------|
| **dev** | shopmate.dev.sctp-sandbox.com | 1-3 | dev-latest |
| **uat** | shopmate.uat.sctp-sandbox.com | 2-5 | prod-latest |
| **prod** | shopmate.sctp-sandbox.com | 3-10 | prod-latest |

## 🔐 Security

- **OIDC authentication** replaces access keys
- **Distroless containers** in UAT/prod (no shell access)
- **Secrets in AWS Secrets Manager** (no hardcoded values)
- **State locking** prevents concurrent modifications
- **Resource tagging** for compliance and cost tracking

---

**Owner**: Group1 | **Project**: ShopMate | **Managed by**: Terraform