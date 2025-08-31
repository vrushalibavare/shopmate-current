# ============================================================================
# MONITORING & OBSERVABILITY
# ============================================================================
# Prometheus, Grafana, and CloudWatch monitoring setup

# Prometheus Security Group
resource "aws_security_group" "prometheus" {
  name_prefix = "prometheus-ecs-${var.environment}"
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
  name              = "/ecs/prometheus-ecs-${var.environment}"
  retention_in_days = 30
}

# Prometheus ECS Service
resource "aws_ecs_service" "prometheus" {
  name            = "prometheus-ecs-${var.environment}"
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
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "${data.aws_ecr_repository.shopmate.repository_url}:prometheus"
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
        "--web.external-url=https://${var.domain_name}/prometheus"
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

  depends_on = [aws_lb_listener.shopmate]
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
  task_role_arn            = aws_iam_role.ecs_task_role.arn

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

      secrets = [
        {
          name      = "GF_SECURITY_ADMIN_PASSWORD"
          valueFrom = aws_secretsmanager_secret.grafana_password.arn
        }
      ]

      environment = [
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

  depends_on = [aws_lb_listener.shopmate]
}