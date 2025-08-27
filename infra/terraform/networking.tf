# ============================================================================
# NETWORKING FOUNDATION
# ============================================================================
# VPC, subnets, security groups, and load balancer configuration
# 
# CREATION FLOW:
# 1. VPC & Subnets (Foundation)
# 2. Security Groups (Network Rules)
# 3. Load Balancer (Traffic Distribution)
# 4. Target Groups (Health Checks)
# 5. Listeners (Traffic Routing)

# ============================================================================
# 1. VPC & SUBNETS - Network Foundation
# ============================================================================

# Using AWS VPC module for standardized and best-practice VPC setup
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "shopmate-vpc-${var.environment}"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]     # ECS tasks run here
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"] # Load balancer runs here

  enable_nat_gateway = true # Private subnets need internet access
  single_nat_gateway = true # Cost optimization
  enable_vpn_gateway = false

  enable_dns_hostnames = true # Required for ECS
  enable_dns_support   = true # Required for ECS
}

# ============================================================================
# 2. SECURITY GROUPS - Network Access Control
# ============================================================================

# Security Group for Load Balancer (Internet-facing)
resource "aws_security_group" "alb" {
  name        = "shopmate-alb-sg-${var.environment}"
  description = "Security group for ALB - allows HTTP/HTTPS from internet"
  vpc_id      = module.vpc.vpc_id

  # Allow HTTP from anywhere (will redirect to HTTPS)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for ECS Tasks (Private)
resource "aws_security_group" "ecs_tasks" {
  name        = "shopmate-ecs-tasks-sg-${var.environment}"
  description = "Security group for ECS tasks - allows traffic only from ALB"
  vpc_id      = module.vpc.vpc_id

  # Allow traffic from ALB only (port 3000 for Node.js app)
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # Reference ALB security group
  }

  # Allow all outbound traffic (for API calls, database access, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================================================
# 3. APPLICATION LOAD BALANCER - Traffic Distribution
# ============================================================================

# Application Load Balancer (Internet-facing)
resource "aws_lb" "shopmate" {
  name               = "shopmate-alb-${var.environment}"
  internal           = false                       # Internet-facing
  load_balancer_type = "application"               # Layer 7 load balancer
  security_groups    = [aws_security_group.alb.id] # Uses ALB security group
  subnets            = module.vpc.public_subnets   # Deployed in public subnets
}

# ============================================================================
# 4. TARGET GROUPS - Health Checks & Routing
# ============================================================================

# Target Group for main application
resource "aws_lb_target_group" "shopmate" {
  name        = "shopmate-tg-${var.environment}"
  port        = 3000   # Node.js app port
  protocol    = "HTTP" # Internal communication
  vpc_id      = module.vpc.vpc_id
  target_type = "ip" # Required for Fargate

  # Health check configuration
  health_check {
    path                = "/health" # App health endpoint
    healthy_threshold   = 3         # 3 successful checks = healthy
    unhealthy_threshold = 2         # 2 failed checks = unhealthy
    timeout             = 5         # 5 second timeout
    interval            = 30        # Check every 30 seconds
    matcher             = "200"     # HTTP 200 = healthy
  }
}

# ============================================================================
# 5. LISTENERS - Traffic Routing Rules
# ============================================================================

# HTTPS Listener (Primary)
resource "aws_lb_listener" "shopmate" {
  load_balancer_arn = aws_lb.shopmate.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.shopmate.certificate_arn # From dns.tf

  # Forward all HTTPS traffic to main application
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.shopmate.arn
  }
}

# HTTP Listener (Redirect to HTTPS)
resource "aws_lb_listener" "shopmate_http" {
  load_balancer_arn = aws_lb.shopmate.arn
  port              = "80"
  protocol          = "HTTP"

  # Redirect all HTTP traffic to HTTPS
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301" # Permanent redirect
    }
  }
}