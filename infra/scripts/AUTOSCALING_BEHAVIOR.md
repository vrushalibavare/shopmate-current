# ShopMate Autoscaling Behavior Guide

## Overview
This document explains the complete autoscaling behavior patterns for ShopMate ECS service, including timing, triggers, and expected outcomes.

## Autoscaling Configuration

### Current Settings
- **CPU Scale-Out Trigger**: 70% average CPU utilization
- **Memory Scale-Out Trigger**: 80% average memory utilization
- **Min Containers**: 1 (dev), 2 (uat), 3 (prod)
- **Max Containers**: 5 (dev), 5 (uat), 10 (prod)
- **Evaluation Period**: 2 data points at 1-minute intervals

### AWS Target Tracking Policy
```terraform
# CPU-based scaling
target_value = 70.0  # Scale when CPU > 70%

# Memory-based scaling  
target_value = 80.0  # Scale when Memory > 80%
```

## Scale-Out Behavior (Load Increase)

### Timeline - First Scale Event (1→2 containers)
```
Time 0-1min:   CPU hits 70%+ → First data point
Time 1-2min:   CPU stays 70%+ → Second data point
Time 2-3min:   CPU stays 70%+ → Autoscaling triggers
Time 3-4min:   New container starting up
Time 4-5min:   New container healthy, load distributes
```

### Timeline - Subsequent Scale Events (2→3, 3→4 containers)
```
Time 0-1min:   CPU still high across existing containers
Time 1-2min:   Faster evaluation (already in scaling mode)
Time 2-3min:   Additional container starts
Time 3-4min:   Load distributes across more containers
```

### Key Characteristics
- **First scaling**: ~3-5 minutes (includes evaluation period)
- **Subsequent scaling**: ~1-2 minutes (faster response)
- **Cascading effect**: Multiple scale events if load persists
- **Load distribution**: CPU drops as containers increase

## Scale-Down Behavior (Load Decrease)

### Timeline - Scale-In Events
```
Time 0min:      Load stops, CPU drops below 70%
Time 0-15min:   Containers remain at peak count (evaluation period)
Time 15-20min:  First scale-down (4→3 containers)
Time 20-35min:  Second scale-down (3→2 containers) if CPU stays low
Time 35-50min:  Final scale-down (2→1 containers) back to baseline
```

### Key Characteristics
- **Much slower than scale-out**: 15-20 minutes per step
- **Conservative approach**: Prevents rapid up/down scaling
- **Sustained low load required**: 15+ minutes below threshold
- **Gradual reduction**: One container at a time

## Why Scale-Down is Slower

### AWS Design Philosophy
1. **Prevent Flapping**: Avoid rapid scaling up and down
2. **Handle Traffic Spikes**: Temporary load drops don't trigger scale-down
3. **Cost vs Performance**: Keep capacity for potential load increases
4. **Stability**: Ensure consistent user experience

### Technical Implementation
- **Longer evaluation period**: More data points required for scale-in
- **Higher confidence threshold**: Need sustained low utilization
- **Cooldown periods**: Minimum time between scaling actions
- **Conservative defaults**: AWS errs on side of maintaining capacity

## Gentle Autoscaling Script Behavior

### Load Pattern
```bash
# Phase 1: Warm-up (30 seconds)
2 concurrent requests → Moderate CPU increase

# Phase 2: Build-up (30 seconds)  
3 concurrent requests → Higher CPU load

# Phase 3: Sustained load (continuous)
4 concurrent requests every 25 seconds → Spiky but sustained average
```

### Why Spiky Pattern Works
- **AWS measures averages**: 1-minute average CPU, not instantaneous
- **Realistic traffic**: Mimics real-world burst patterns
- **Sustained average**: Spikes average to 70%+ over time
- **Triggers scaling**: Based on average utilization

### Expected Dashboard Behavior
```
Stress Load Panel:    Spikes every 25 seconds (4 requests)
Service CPU Panel:    Sustained 70%+ average (triggers scaling)
Container Count:      Increases after 3-5 minutes
Individual CPU:       Shows random container (ALB routing)
```

## Testing Complete Autoscaling Cycle

### Scale-Out Test (5-10 minutes)
```bash
# Start load generation
cd infra/scripts
./gentle-autoscaling.sh

# Monitor scaling
./monitor-scaling.sh

# Expected: 1→2→3 containers over 5-10 minutes
```

### Scale-Down Test (30-60 minutes)
```bash
# Stop load generation
Ctrl+C (stop gentle-autoscaling.sh)

# Continue monitoring
./monitor-scaling.sh

# Expected: 3→2→1 containers over 30-60 minutes
```

## Monitoring and Verification

### Key Metrics to Watch
1. **Service CPU**: Should average 70%+ during load, drop after scaling
2. **Container Count**: Should increase during load, decrease slowly after
3. **Individual CPU**: Shows random container performance
4. **Stress Load**: Shows request pattern causing the load

### Verification Commands
```bash
# Check current service status
aws ecs describe-services --cluster shopmate-dev --services shopmate-service-dev --query "services[0].{desired:desiredCount,running:runningCount}" --region ap-southeast-1

# Check recent CPU metrics
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization --dimensions Name=ServiceName,Value=shopmate-service-dev Name=ClusterName,Value=shopmate-dev --start-time $(date -u -v-10M +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Average --region ap-southeast-1
```

## Stateless Architecture Validation

### During Autoscaling
```bash
# Test application functionality during scaling
curl https://shopmate.dev.sctp-sandbox.com/
curl https://shopmate.dev.sctp-sandbox.com/products

# Add items to cart (tests session persistence)
curl -X POST https://shopmate.dev.sctp-sandbox.com/cart/add -d "productId=1&quantity=2"

# Verify cart persists across containers
curl https://shopmate.dev.sctp-sandbox.com/cart
```

### Expected Results
- ✅ All requests succeed during scaling
- ✅ Cart data persists across different containers
- ✅ No session loss during container changes
- ✅ Seamless user experience

## Troubleshooting

### Scale-Out Not Triggering
- **Check CPU metrics**: Ensure sustained 70%+ for 2+ minutes
- **Verify load generation**: Confirm stress requests are reaching application
- **Check container limits**: Ensure not at max capacity
- **Review IAM permissions**: ECS needs autoscaling permissions

### Scale-Down Not Happening
- **Be patient**: Scale-down takes 15-20 minutes per step
- **Verify low CPU**: Ensure CPU consistently below 70%
- **Check for background load**: Other traffic might keep CPU elevated
- **Monitor for full cycle**: Complete scale-down can take 30-60 minutes

### Unexpected Scaling Behavior
- **Review CloudWatch metrics**: Check actual vs expected CPU patterns
- **Verify target tracking**: Ensure policies are correctly configured
- **Check for memory scaling**: Memory limits might also trigger scaling
- **Monitor application logs**: Look for errors affecting performance

## Best Practices

### For Testing
- **Allow sufficient time**: Plan 60+ minutes for complete cycle
- **Monitor multiple metrics**: CPU, memory, request rates
- **Test stateless behavior**: Verify application works during scaling
- **Document observations**: Record actual vs expected timing

### For Production
- **Tune thresholds**: Adjust CPU/memory targets based on application behavior
- **Set appropriate limits**: Configure min/max containers for workload
- **Monitor costs**: Track scaling patterns and associated costs
- **Plan for peak loads**: Ensure max capacity handles expected traffic

This behavior is normal AWS autoscaling operation designed for production stability and cost optimization.