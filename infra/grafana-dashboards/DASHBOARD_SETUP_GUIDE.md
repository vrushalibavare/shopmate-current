# ShopMate Autoscaling Dashboard Setup Guide

## Overview
This guide documents the complete setup of the ShopMate Autoscaling Grafana dashboard with multi-data source configuration.

## Data Sources Required

### 1. Prometheus Data Source
- **Name**: `Prometheus-ShopMate`
- **Type**: Prometheus
- **URL**: `https://shopmate.dev.sctp-sandbox.com/prometheus`
- **Access**: Server (default)
- **Authentication**: None

### 2. CloudWatch Data Source
- **Name**: `CloudWatch-ECS`
- **Type**: CloudWatch
- **Authentication Provider**: `AWS SDK Default`
- **Default Region**: `ap-southeast-1`
- **Access**: Server (default)

## Dashboard Panels Configuration

### Panel 1: ECS Service CPU (Autoscaling Trigger)
**Purpose**: Shows service-level CPU that triggers autoscaling at 70%

**Configuration**:
- **Data Source**: CloudWatch-ECS
- **Namespace**: `AWS/ECS`
- **Metric Name**: `CPUUtilization`
- **Dimensions**:
  - `ServiceName`: `shopmate-service-dev`
  - `ClusterName`: `shopmate-dev`
- **Statistic**: `Average`
- **Period**: `1m`

**Panel Settings**:
- **Title**: "ECS Service CPU (Autoscaling Trigger)"
- **Visualization**: Time series
- **Unit**: Percent (0-100)
- **Min**: 0, **Max**: 100
- **Threshold**: 70% (Red line)

### Panel 2: Container Count (Scaling Evidence)
**Purpose**: Shows number of active containers (1→2→3 during scaling)

**Configuration**:
- **Data Source**: CloudWatch-ECS
- **Namespace**: `AWS/ECS`
- **Metric Name**: `CPUUtilization`
- **Dimensions**:
  - `ServiceName`: `shopmate-service-dev`
  - `ClusterName`: `shopmate-dev`
- **Statistic**: `SampleCount`
- **Period**: `1m`

**Panel Settings**:
- **Title**: "Container Count"
- **Visualization**: Time series
- **Unit**: Short (whole numbers)
- **Min**: 0

**Note**: Uses SampleCount as proxy for container count since RunningTaskCount may not be available.

### Panel 3: Stress Load (Load Generator)
**Purpose**: Shows stress test requests that cause CPU load

**Configuration**:
- **Data Source**: Prometheus-ShopMate
- **Query**: `http_requests_total{route="/stress"}`
- **Query Type**: Range

**Panel Settings**:
- **Title**: "Stress Load req/sec"
- **Visualization**: Time series
- **Unit**: Requests/sec

### Panel 4: Individual Container CPU (Single Container View)
**Purpose**: Shows CPU of individual container (random due to ALB routing)

**Configuration**:
- **Data Source**: Prometheus-ShopMate
- **Query**: `rate(nodejs_process_cpu_seconds_total[30s]) * 100`
- **Query Type**: Range

**Panel Settings**:
- **Title**: "Individual Container CPU%"
- **Visualization**: Time series
- **Unit**: Percent (0-100)
- **Min**: 0, **Max**: 100

## Dashboard Settings

### Time Configuration
- **Time Range**: Last 15 minutes
- **Auto Refresh**: 5 seconds
- **Timezone**: Browser

### Layout
```
Row 1: [ECS Service CPU] [Stress Load]
Row 2: [Individual CPU] [Container Count]
```

## Expected Behavior During Autoscaling

### Complete Autoscaling Cycle
**Scale-Out (Fast - 3-5 minutes):**
1. **0-2min**: Stress Load increases, CPU climbs
2. **2-4min**: Service CPU hits 70%+, sustained load
3. **4-6min**: Container Count increases from 1→2 (first scaling)
4. **6-8min**: Service CPU drops, load distributed
5. **8-10min**: If needed, scales 2→3 (faster subsequent scaling)

**Scale-Down (Slow - 15-20 minutes per step):**
1. **Stop stress test**: CPU drops below 70%
2. **15-20min later**: First scale-down (conservative)
3. **15-20min intervals**: Additional scale-downs if CPU stays low
4. **Total time**: 30-60 minutes to return to baseline

### Panel Correlations
- **Stress Load spikes** → **Service CPU increases**
- **Service CPU sustained 70%+** → **Container Count increases** (3-5 min delay)
- **Container Count increases** → **Service CPU decreases**
- **Stress Load stops** → **Service CPU drops** → **Container Count decreases** (15-20 min delay)
- **Individual CPU** shows random container metrics (ALB routing)

### Why Scale-Down is Slower
- **Prevents flapping**: Avoids rapid up/down scaling
- **Handles traffic spikes**: Temporary load drops don't trigger scale-down
- **Cost optimization**: Keeps capacity for potential load increases
- **Evaluation period**: 15+ minutes of sustained low CPU required
- **AWS best practice**: Conservative scale-in vs aggressive scale-out

## Troubleshooting

### CloudWatch Data Source Issues
**Error**: "Access Denied" or "No EC2 IMDS role found"
**Solution**: Ensure Grafana task has CloudWatch read permissions:
```terraform
# Add to ECS task role
"cloudwatch:GetMetricStatistics",
"cloudwatch:ListMetrics",
"cloudwatch:GetMetricData"
```

### Missing Metrics
**Issue**: `/stress` route not appearing
**Solution**: Make test request first:
```bash
curl -k https://shopmate.dev.sctp-sandbox.com/stress?duration=5000
```

### No Container Count Data
**Issue**: RunningTaskCount not available
**Solution**: Use CPUUtilization with SampleCount statistic as proxy

## Alternative Metrics

### For Memory Monitoring (Optional Panel 5)
**Configuration**:
- **Data Source**: CloudWatch-ECS
- **Namespace**: `AWS/ECS`
- **Metric Name**: `MemoryUtilization`
- **Dimensions**: Same as CPU
- **Threshold**: 80% (Memory autoscaling trigger)

### For Application Metrics (Separate Dashboard)
**Prometheus Queries**:
- Cart Operations: `rate(cart_items_added_total[30s])`
- Orders Created: `rate(orders_created_total[30s])`
- Product Views: `rate(product_views_total[30s])`
- Order Value: `order_value_total`

## Import/Export

### Export Dashboard
1. Dashboard Settings → JSON Model
2. Copy JSON content
3. Save as `shopmate-autoscaling.json`

### Import Dashboard
1. Grafana → + → Import
2. Upload JSON file or paste content
3. Configure data source UIDs if needed

## Testing the Dashboard

### Start Autoscaling Test
```bash
cd infra/scripts
./gentle-autoscaling.sh
```

### Monitor in Parallel
```bash
cd infra/scripts
./monitor-scaling.sh
```

### Verify Stateless Architecture
```bash
# Test during scaling
curl https://shopmate.dev.sctp-sandbox.com/
curl https://shopmate.dev.sctp-sandbox.com/products
```

## Key Insights

### Why This Dashboard Works
- **Multi-data source**: CloudWatch for infrastructure, Prometheus for application
- **Complete story**: Load generation → CPU spike → Scaling → Load distribution
- **Real-time**: 5-second refresh shows autoscaling in action
- **Stateless proof**: Application continues working during scaling

### Limitations
- **Individual CPU**: Shows only one container (ALB routing limitation)
- **CloudWatch delay**: 1-2 minute lag in ECS metrics
- **Prometheus scope**: Limited to single container metrics via ALB

This dashboard provides comprehensive visibility into AWS ECS autoscaling behavior and demonstrates the effectiveness of stateless architecture.