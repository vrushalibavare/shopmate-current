# ============================================================================
# CONTAINER ORCHESTRATION
# ============================================================================
# ECS cluster, task definitions, and services for containerized applications
#
# CREATION FLOW:
# 1. ECS Cluster (Container Orchestration Platform)
# 2. CloudWatch Log Groups (Centralized Logging)
# 3. Task Definition (Container Blueprint)
# 4. ECS Service (Running Container Management)

# ============================================================================
# 1. ECS CLUSTER - Container Orchestration Platform
# ============================================================================

# ECS Cluster for running containerized applications
resource "aws_ecs_cluster" "shopmate" {
  name = "shopmate-ecs-${var.environment}"
  # Fargate cluster - serverless container platform
  # No EC2 instances to manage
}

# ============================================================================
# 2. CLOUDWATCH LOG GROUPS - Centralized Logging
# ============================================================================

# Log group for main application container logs
resource "aws_cloudwatch_log_group" "shopmate" {
  name              = "/ecs/shopmate-lg-${var.environment}"
  retention_in_days = 30 # Keep logs for 30 days (cost optimization)
}

# ============================================================================
# 3. TASK DEFINITION - Container Blueprint
# ============================================================================

# Task definition defines how containers should run
resource "aws_ecs_task_definition" "shopmate" {
  family                   = "shopmate-td-${var.environment}"
  network_mode             = "awsvpc"                                 # Each task gets its own ENI
  requires_compatibilities = ["FARGATE"]                              # Serverless containers
  cpu                      = var.task_cpu                             # From variables (environment-specific)
  memory                   = var.task_memory                          # From variables (environment-specific)
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # From iam.tf
  task_role_arn            = aws_iam_role.ecs_task_role.arn           # From iam.tf

  # Container configuration
  container_definitions = jsonencode([
    {
      name      = "shopmate-container-${var.environment}"                               # Container name
      image     = "${data.aws_ecr_repository.shopmate.repository_url}:${var.image_tag}" # From shared ECR repository
      essential = true                                                                  # If this container stops, stop the task

      # Network configuration
      portMappings = [
        {
          containerPort = 3000 # Node.js application port
          protocol      = "tcp"
        }
      ]

      # Environment variables (non-sensitive configuration)
      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment # dev/uat/prod
        },
        {
          name  = "PORT"
          value = "3000" # Application port
        },
        {
          name  = "PRODUCTS_TABLE"
          value = aws_dynamodb_table.products.name # From storage.tf
        },
        {
          name  = "ORDERS_TABLE"
          value = aws_dynamodb_table.orders.name
        },
        {
          name  = "CARTS_TABLE"
          value = aws_dynamodb_table.carts.name
        },
        {
          name  = "SESSIONS_TABLE"
          value = aws_dynamodb_table.sessions.name
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]

      # Secrets (sensitive configuration from Secrets Manager)
      secrets = [
        {
          name      = "SESSION_SECRET"
          valueFrom = aws_secretsmanager_secret.session_secret.arn # From iam.tf
        }
      ]

      # Logging configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.shopmate.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "shopmate-logs-${var.environment}"
        }
      }
    }
  ])
}

# ============================================================================
# 4. ECS SERVICE - Running Container Management
# ============================================================================

# ECS Service manages running containers and integrates with load balancer
resource "aws_ecs_service" "shopmate" {
  name            = "shopmate-service-${var.environment}"
  cluster         = aws_ecs_cluster.shopmate.id
  task_definition = aws_ecs_task_definition.shopmate.arn
  desired_count   = var.app_count_min # Initial number of containers
  launch_type     = "FARGATE"         # Serverless containers

  # Enable ECS Exec for dev environment only (debugging capability)
  enable_execute_command = var.environment == "dev" ? true : false

  # Network configuration
  network_configuration {
    subnets          = module.vpc.private_subnets        # From networking.tf
    security_groups  = [aws_security_group.ecs_tasks.id] # From networking.tf
    assign_public_ip = false                             # Private subnets, no direct internet access
  }

  # Load balancer integration
  load_balancer {
    target_group_arn = aws_lb_target_group.shopmate.arn        # From networking.tf
    container_name   = "shopmate-container-${var.environment}" # Must match container name
    container_port   = 3000                                    # Must match container port
  }

  # Ensure load balancer is ready before creating service
  depends_on = [aws_lb_listener.shopmate] # From networking.tf
}