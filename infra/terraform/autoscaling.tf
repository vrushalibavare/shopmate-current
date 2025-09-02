# ============================================================================
# AUTO SCALING CONFIGURATION
# ============================================================================
# Automatic horizontal scaling based on CPU and memory utilization
#
# CREATION FLOW:
# 1. Auto Scaling Target (Define Scalable Resource)
# 2. CPU Scaling Policy (Scale Based on CPU Usage)
# 3. Memory Scaling Policy (Scale Based on Memory Usage)
#
# SCALING BEHAVIOR:
# - Scale OUT when CPU > 70% OR Memory > 80%
# - Scale IN when CPU < 70% AND Memory < 80%
# - Faster response times than AWS defaults for better performance

# ============================================================================
# 1. AUTO SCALING TARGET - Define Scalable Resource
# ============================================================================

# Define the ECS service as a scalable target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.app_count_max                                                           # Environment-specific max (dev:3, uat:5, prod:10)
  min_capacity       = var.app_count_min                                                           # Environment-specific min (dev:1, uat:2, prod:3)
  resource_id        = "service/${aws_ecs_cluster.shopmate.name}/${aws_ecs_service.shopmate.name}" # From ecs.tf
  scalable_dimension = "ecs:service:DesiredCount"                                                  # Scale the number of tasks
  service_namespace  = "ecs"                                                                       # ECS service namespace
}

# ============================================================================
# 2. CPU SCALING POLICY - Scale Based on CPU Usage
# ============================================================================

# CPU-based auto scaling with target tracking
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "shopmate-ecs-cpu-scaling-${var.environment}"
  policy_type        = "TargetTrackingScaling" # Automatically adjust to maintain target
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization" # AWS managed metric
    }
    target_value       = 70.0 # Target 70% CPU utilization
    scale_out_cooldown = 60   # Wait 60s before scaling out again (default: 300s)
    scale_in_cooldown  = 180  # Wait 180s before scaling in again (default: 900s)

    # Faster response times for better performance under load
  }
}

# ============================================================================
# 3. MEMORY SCALING POLICY - Scale Based on Memory Usage
# ============================================================================

# Memory-based auto scaling with target tracking
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  name               = "shopmate-ecs-memory-scaling-${var.environment}"
  policy_type        = "TargetTrackingScaling" # Automatically adjust to maintain target
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization" # AWS managed metric
    }
    target_value       = 80.0 # Target 80% memory utilization (higher than CPU)
    scale_out_cooldown = 60   # Wait 60s before scaling out again
    scale_in_cooldown  = 180  # Wait 180s before scaling in again

    # Memory threshold higher than CPU to avoid premature scaling
    # Memory usage is typically more stable than CPU spikes
  }
}