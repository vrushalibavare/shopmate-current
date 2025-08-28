# Workflow Test Scripts

Essential scripts for testing GitHub Actions workflows.

## Scripts

### `test-stage-deployment.sh`
- **Purpose**: Test UAT deployment workflow
- **Branch**: Run from `dev` branch
- **Trigger**: Creates dev → stage PR
- **Usage**: `./test-stage-deployment.sh`

### `test-production-deployment.sh`
- **Purpose**: Test production deployment workflow  
- **Branch**: Run from `stage` branch
- **Trigger**: Creates stage → production PR
- **Usage**: `./test-production-deployment.sh`

## Workflow

```
dev → stage → production
 ↓      ↓        ↓
dev   uat     prod
```

Each script automatically creates test changes to enable meaningful PRs.