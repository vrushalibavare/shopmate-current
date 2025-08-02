# ShopMate Scripts

This directory contains utility scripts for testing and monitoring the ShopMate application.

## Available Scripts

### Auto-scaling Testing
- **[autoscaling-test.sh](autoscaling-test.sh)** - Load testing script to trigger auto-scaling
- **[monitor-scaling.sh](monitor-scaling.sh)** - Monitor ECS service scaling metrics

## Usage

### Auto-scaling Test
```bash
# Test auto-scaling for dev environment
./scripts/autoscaling-test.sh dev

# Test with custom parameters
./scripts/autoscaling-test.sh prod 100 30
```

### Monitor Scaling
```bash
# Monitor dev environment scaling
./scripts/monitor-scaling.sh dev

# Monitor with custom interval
./scripts/monitor-scaling.sh prod 10
```

## Notes

- **Deployment and Destroy**: Use GitHub Actions workflows instead of scripts
- **Secret Management**: Handled automatically by Terraform with AWS Secrets Manager
- **Infrastructure Management**: Use Terraform commands in environment directories

## Deprecated Scripts

The following scripts have been replaced by automated workflows:
- `deploy.sh` → Use GitHub Actions dev/stage/production workflows
- `destroy.sh` → Use GitHub Actions destroy workflow
- `generate-secrets.sh` → Terraform generates secrets automatically