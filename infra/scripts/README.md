# ShopMate Autoscaling Scripts

Essential scripts for testing and monitoring ECS Fargate autoscaling.

## Scripts

### `gentle-autoscaling.sh`
**Purpose**: Gradual load testing to trigger smooth autoscaling
**Usage**: 
```bash
./gentle-autoscaling.sh [environment]

# Examples:
./gentle-autoscaling.sh dev
./gentle-autoscaling.sh uat
./gentle-autoscaling.sh prod
```

**How it works**:
- Phase 1: Starts with 2 concurrent requests
- Phase 2: Increases to 3 requests  
- Phase 3: Steady 4 requests every 25 seconds
- Each request runs for 20 seconds of CPU work
- Designed to gradually increase CPU to trigger autoscaling

### `monitor-scaling.sh`
**Purpose**: Monitor ECS service scaling metrics in real-time
**Usage**:
```bash
./monitor-scaling.sh [environment] [interval_seconds]

# Examples:
./monitor-scaling.sh dev
./monitor-scaling.sh uat 10
```

**Shows**:
- Current task count
- CPU and memory utilization
- Scaling events
- Target tracking metrics

## Testing Workflow

1. **Start monitoring**: `./monitor-scaling.sh dev`
2. **Start load test**: `./gentle-autoscaling.sh dev` 
3. **Watch scaling**: Monitor shows tasks scaling up when CPU > 70%
4. **Stop test**: Ctrl+C to stop load, watch scale-down after 10-15 minutes

## Notes

- **Scaling triggers**: CPU > 70% for 2 minutes → scale up
- **Scale down**: CPU < 70% for 15 minutes → scale down  
- **Gentle approach**: Avoids overwhelming containers
- **Environment-specific**: Gets URLs from Terraform outputs