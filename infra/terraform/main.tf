# ============================================================================
# SHOPMATE E-COMMERCE TERRAFORM CONFIGURATION
# ============================================================================
# This configuration creates a complete AWS infrastructure for the ShopMate
# e-commerce application using ECS Fargate, DynamoDB, and Application Load Balancer

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# 1. NETWORKING FOUNDATION
# ============================================================================
# Using AWS VPC module for standardized and best-practice VPC setup

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "shopmate-vpc-${var.environment}"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.environment
  }
}

# Security Group for Load Balancer
resource "aws_security_group" "alb" {
  name        = "shopmate-alb-sg-${var.environment}"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "shopmate-ecs-tasks-sg-${var.environment}"
  description = "Security group for ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================================================
# 2. SSL/TLS CERTIFICATE & DNS MANAGEMENT
# ============================================================================
# Manages SSL certificates and DNS records for secure HTTPS access

# Route53 Zone Management - Uses existing or creates new zone
# Conditional resource creation based on variable
data "aws_route53_zone" "selected" {
  count = var.create_route53_zone ? 0 : 1
  name  = var.route53_zone_name
}

resource "aws_route53_zone" "primary" {
  count = var.create_route53_zone ? 1 : 0
  name  = var.route53_zone_name
}

# Local value to reference the correct zone ID
locals {
  route53_zone_id = var.create_route53_zone ? aws_route53_zone.primary[0].zone_id : data.aws_route53_zone.selected[0].zone_id
}

# SSL Certificate - Provides HTTPS encryption
resource "aws_acm_certificate" "shopmate" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "shopmate-cert-${var.environment}"
  }
}

# Certificate validation DNS records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.shopmate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.route53_zone_id
}

# Certificate validation resource
resource "aws_acm_certificate_validation" "shopmate" {
  certificate_arn         = aws_acm_certificate.shopmate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# DNS A record pointing to load balancer
resource "aws_route53_record" "shopmate" {
  zone_id = local.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.shopmate.dns_name
    zone_id                = aws_lb.shopmate.zone_id
    evaluate_target_health = true
  }
}

# ============================================================================
# 3. CONTAINER REGISTRY
# ============================================================================
# ECR repository for storing Docker images with lifecycle management

# ECR Repository - Stores Docker images
resource "aws_ecr_repository" "shopmate" {
  name                 = "shopmate"
  image_tag_mutability = "MUTABLE"
}

# ECR Lifecycle Policy - Manages image retention to control costs
resource "aws_ecr_lifecycle_policy" "shopmate" {
  repository = aws_ecr_repository.shopmate.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ============================================================================
# 4. DATABASE LAYER
# ============================================================================
# DynamoDB tables for application data storage with pay-per-request billing

# Products table - Stores product catalog
resource "aws_dynamodb_table" "products" {
  name         = "shopmate-products-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "N"
  }
}

# Orders table - Stores customer orders
resource "aws_dynamodb_table" "orders" {
  name         = "shopmate-orders-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Carts table - Stores shopping cart data
resource "aws_dynamodb_table" "carts" {
  name         = "shopmate-carts-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }
}

# Sessions table - Stores user sessions for stateless architecture
resource "aws_dynamodb_table" "sessions" {
  name         = "shopmate-sessions-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  ttl {
    attribute_name = "expires"
    enabled        = true
  }
}

# ============================================================================
# 5. SECRETS MANAGEMENT
# ============================================================================
# Secure storage and management of application secrets

# Generate secure session secret
resource "random_password" "session_secret" {
  length  = 64
  special = true
}

# Secrets Manager secret for session management
resource "aws_secretsmanager_secret" "session_secret" {
  name                    = "shopmate-session-key-${var.environment}"
  description             = "Session secret for ShopMate ${var.environment}"
  force_overwrite_replica_secret = true
  recovery_window_in_days = 0
}

# Store the generated secret
resource "aws_secretsmanager_secret_version" "session_secret" {
  secret_id     = aws_secretsmanager_secret.session_secret.id
  secret_string = random_password.session_secret.result
}

# ============================================================================
# 6. IAM ROLES & POLICIES
# ============================================================================
# Identity and Access Management for ECS tasks and AWS service integration

# ECS Task Execution Role - Allows ECS to pull images and write logs
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "shopmate-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role - Allows application to access AWS services
resource "aws_iam_role" "ecs_task_role" {
  name = "shopmate-task-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# DynamoDB access policy - Allows CRUD operations on tables
resource "aws_iam_policy" "dynamodb_access" {
  name        = "shopmate-dynamodb-access-${var.environment}"
  description = "Allow access to DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Effect = "Allow"
        Resource = [
          aws_dynamodb_table.products.arn,
          aws_dynamodb_table.orders.arn,
          aws_dynamodb_table.carts.arn,
          aws_dynamodb_table.sessions.arn
        ]
      }
    ]
  })
}

# Secrets Manager access policy - Allows reading secrets
resource "aws_iam_policy" "secrets_access" {
  name        = "shopmate-secrets-access-${var.environment}"
  description = "Allow access to Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.session_secret.arn
      }
    ]
  })
}

# Attach policies to roles
resource "aws_iam_role_policy_attachment" "execution_role_secrets" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

resource "aws_iam_role_policy_attachment" "task_role_dynamodb" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

resource "aws_iam_role_policy_attachment" "task_role_secrets" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# ============================================================================
# 7. LOAD BALANCER & TARGET GROUP
# ============================================================================
# Application Load Balancer for distributing traffic and SSL termination

# Application Load Balancer - Distributes incoming traffic
resource "aws_lb" "shopmate" {
  name               = "shopmate-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets
}

# Target Group - Defines health check and routing for containers
resource "aws_lb_target_group" "shopmate" {
  name        = "shopmate-tg-${var.environment}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

# Health Check - Monitors the health of the application. Defined in app.js for /health endpoint
  health_check {
    path                = "/health"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# Prometheus Target Group
resource "aws_lb_target_group" "prometheus" {
  name        = "prometheus-tg-${var.environment}"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/prometheus/-/ready"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# Prometheus ALB Listener Rule
resource "aws_lb_listener_rule" "prometheus" {
  listener_arn = aws_lb_listener.shopmate.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }

  condition {
    path_pattern {
      values = ["/prometheus", "/prometheus/*"]
    }
  }
}

# HTTPS Listener - Handles secure traffic
resource "aws_lb_listener" "shopmate" {
  load_balancer_arn = aws_lb.shopmate.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.shopmate.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.shopmate.arn
  }
}

# HTTP Listener - Redirects to HTTPS
resource "aws_lb_listener" "shopmate_http" {
  load_balancer_arn = aws_lb.shopmate.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ============================================================================
# 8. CONTAINER ORCHESTRATION
# ============================================================================
# Using AWS ECS module for standardized ECS setup

# ECS Cluster
resource "aws_ecs_cluster" "shopmate" {
  name = "shopmate-${var.environment}"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "shopmate" {
  family                   = "shopmate-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "shopmate"
      image     = "${aws_ecr_repository.shopmate.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = "3000"
        },
        {
          name  = "PRODUCTS_TABLE"
          value = aws_dynamodb_table.products.name
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

      secrets = [
        {
          name      = "SESSION_SECRET"
          valueFrom = aws_secretsmanager_secret.session_secret.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.shopmate.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "shopmate"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "shopmate" {
  name            = "shopmate-service-${var.environment}"
  cluster         = aws_ecs_cluster.shopmate.id
  task_definition = aws_ecs_task_definition.shopmate.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.shopmate.arn
    container_name   = "shopmate"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.shopmate]


}



# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "shopmate" {
  name              = "/ecs/shopmate-${var.environment}"
  retention_in_days = 30
}

# ============================================================================
# PROMETHEUS MONITORING SETUP
# ============================================================================

# Prometheus ECS Service
resource "aws_ecs_service" "prometheus" {
  name            = "prometheus-${var.environment}"
  cluster         = aws_ecs_cluster.shopmate.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.prometheus.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }
}

# Prometheus Task Definition
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "${aws_ecr_repository.shopmate.repository_url}:prometheus"
      essential = true

      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]

      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--web.console.libraries=/etc/prometheus/console_libraries",
        "--web.console.templates=/etc/prometheus/consoles",
        "--web.route-prefix=/prometheus",
        "--web.external-url=https://shopmate.dev.sctp-sandbox.com/prometheus"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "prometheus"
        }
      }
    }
  ])
}

# Prometheus Security Group
resource "aws_security_group" "prometheus" {
  name_prefix = "prometheus-${var.environment}"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Prometheus CloudWatch Log Group
resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/prometheus-${var.environment}"
  retention_in_days = 30
}

# ============================================================================
# GRAFANA MONITORING SETUP
# ============================================================================

# Grafana ECS Service
resource "aws_ecs_service" "grafana" {
  name            = "grafana-${var.environment}"
  cluster         = aws_ecs_cluster.shopmate.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.grafana.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }
}

# Grafana Task Definition
resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = "admin123"
        },
        {
          name  = "GF_SERVER_ROOT_URL"
          value = "https://${var.domain_name}/grafana"
        },
        {
          name  = "GF_SERVER_SERVE_FROM_SUB_PATH"
          value = "true"
        },
        {
          name  = "PROMETHEUS_URL"
          value = "https://${var.domain_name}/prometheus"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "grafana"
        }
      }
    }
  ])
}

# Grafana Target Group
resource "aws_lb_target_group" "grafana" {
  name        = "grafana-tg-${var.environment}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# Grafana ALB Listener Rule
resource "aws_lb_listener_rule" "grafana" {
  listener_arn = aws_lb_listener.shopmate.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }
}

# Grafana Security Group
resource "aws_security_group" "grafana" {
  name_prefix = "grafana-${var.environment}"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Grafana CloudWatch Log Group
resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/grafana-${var.environment}"
  retention_in_days = 30
}





# ============================================================================
# 9. AUTO SCALING CONFIGURATION
# ============================================================================
# Automatic scaling based on CPU and memory utilization

# Auto Scaling Target - Defines scaling parameters
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.environment == "prod" ? 10 : 5
  min_capacity       = var.app_count
  resource_id        = "service/${aws_ecs_cluster.shopmate.name}/${aws_ecs_service.shopmate.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU-based scaling policy
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "shopmate-cpu-scaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Memory-based scaling policy
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  name               = "shopmate-memory-scaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# ============================================================================
# 10. MONITORING & OBSERVABILITY
# ============================================================================
# CloudWatch dashboard for monitoring application performance and health

# CloudWatch Dashboard - Provides operational visibility
resource "aws_cloudwatch_dashboard" "shopmate" {
  dashboard_name = "shopmate-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.shopmate.name, "ClusterName", aws_ecs_cluster.shopmate.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Resources"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "RunningTaskCount", "ServiceName", aws_ecs_service.shopmate.name, "ClusterName", aws_ecs_cluster.shopmate.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Container Count"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.shopmate.arn_suffix],
            [".", "TargetResponseTime", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Traffic & Response Time"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.orders.name],
            [".", "ConsumedWriteCapacityUnits", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Orders Database Activity"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.shopmate.name}' | fields @timestamp, @message | filter @message like /order/ | sort @timestamp desc | limit 50"
          region = var.aws_region
          title  = "Order Activity Logs"
        }
      }
    ]
  })
}