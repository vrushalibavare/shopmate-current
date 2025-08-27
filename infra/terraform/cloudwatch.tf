# ============================================================================
# CLOUDWATCH MONITORING & DASHBOARDS
# ============================================================================
# CloudWatch dashboard for monitoring application performance and health
#
# DASHBOARD LAYOUT:
# Row 1: Infrastructure Health (ECS Resources | Container Count | Traffic & Response Time)
# Row 2: Business Metrics (Orders Placed | Cart Activity | Checkouts Completed)
# Row 3: Technical Details (DynamoDB Activity | Application Errors)
#
# PURPOSE:
# - Real-time operational visibility
# - Performance monitoring and alerting
# - Troubleshooting and debugging support

# ============================================================================
# CLOUDWATCH METRIC FILTERS - Business Intelligence
# ============================================================================

# Extract business metrics from application logs
resource "aws_cloudwatch_log_metric_filter" "cart_additions" {
  name           = "cart-additions-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.shopmate.name
  pattern        = "Added product"

  metric_transformation {
    name      = "CartAdditions"
    namespace = "ShopMate/Business"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "orders_placed" {
  name           = "orders-placed-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.shopmate.name
  pattern        = "POST"

  metric_transformation {
    name      = "OrdersPlaced"
    namespace = "ShopMate/Business"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "product_views" {
  name           = "product-views-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.shopmate.name
  pattern        = "GET"

  metric_transformation {
    name      = "ProductViews"
    namespace = "ShopMate/Business"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "application-errors-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.shopmate.name
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "ShopMate/Errors"
    value     = "1"
  }
}

# ============================================================================
# CLOUDWATCH DASHBOARD - Operational Visibility
# ============================================================================

# Comprehensive dashboard with CPU/Memory consumption patterns
resource "aws_cloudwatch_dashboard" "shopmate" {
  dashboard_name = "shopmate-dashboard-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: CPU Utilization with Resource Info
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.shopmate.name, "ClusterName", aws_ecs_cluster.shopmate.name]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "CPU Usage (${var.task_cpu} CPU units allocated)"
          annotations = {
            horizontal = [
              {
                label = "Scale Up Threshold"
                value = 70
                color = "#d62728"
              },
              {
                label = "Scale Down Threshold"
                value = 30
                color = "#2ca02c"
              }
            ]
          }
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },

      # Widget 2: Memory Utilization with Resource Info
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ServiceName", aws_ecs_service.shopmate.name, "ClusterName", aws_ecs_cluster.shopmate.name]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "Memory Usage (${var.task_memory}MB allocated)"
          annotations = {
            horizontal = [
              {
                label = "High Usage"
                value = 80
                color = "#ff7f0e"
              }
            ]
          }
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },

      # Widget 3: Running Task Count
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "RunningTaskCount", "ServiceName", aws_ecs_service.shopmate.name, "ClusterName", aws_ecs_cluster.shopmate.name]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "Container Count (${var.app_count_min}-${var.app_count_max} range)"
          annotations = {
            horizontal = [
              {
                label = "Min Capacity"
                value = var.app_count_min
                color = "#2ca02c"
              },
              {
                label = "Max Capacity"
                value = var.app_count_max
                color = "#d62728"
              }
            ]
          }
        }
      },

      # Widget 4: CPU Reservation vs Utilization
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUReservation", "ClusterName", aws_ecs_cluster.shopmate.name, { "label" : "CPU Reserved" }],
            [".", "CPUUtilization", "ServiceName", aws_ecs_service.shopmate.name, "ClusterName", aws_ecs_cluster.shopmate.name, { "label" : "CPU Used" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "CPU: Reserved vs Used (${var.environment} - ${var.task_cpu} units per task)"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },

      # Widget 5: Memory Reservation vs Utilization
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "MemoryReservation", "ClusterName", aws_ecs_cluster.shopmate.name, { "label" : "Memory Reserved" }],
            [".", "MemoryUtilization", "ServiceName", aws_ecs_service.shopmate.name, "ClusterName", aws_ecs_cluster.shopmate.name, { "label" : "Memory Used" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "Memory: Reserved vs Used (${var.environment} - ${var.task_memory}MB per task)"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },

      # Widget 6: Load Balancer Metrics
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.shopmate.arn_suffix, { "stat" : "Sum" }],
            [".", "TargetResponseTime", ".", ".", { "stat" : "Average", "yAxis" : "right" }]
          ]
          period = 60
          region = var.aws_region
          title  = "Traffic & Response Time"
          yAxis = {
            right = {
              label = "Response Time (seconds)"
            }
            left = {
              label = "Request Count"
            }
          }
        }
      },

      # Widget 7: Resource Efficiency
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.shopmate.name, "ClusterName", aws_ecs_cluster.shopmate.name, { "label" : "CPU %" }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { "label" : "Memory %" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Resource Efficiency (5min avg) - ${var.environment}"
          annotations = {
            horizontal = [
              {
                label = "Optimal Range (30-70%)"
                value = 30
                fill  = "above"
                color = "#2ca02c"
              },
              {
                value = 70
                fill  = "below"
                color = "#2ca02c"
              }
            ]
          }
        }
      }
    ]
  })
}