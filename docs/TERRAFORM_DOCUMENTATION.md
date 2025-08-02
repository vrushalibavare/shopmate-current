# ShopMate Terraform Infrastructure Documentation

This document provides a comprehensive explanation of the Terraform configuration for the ShopMate e-commerce application deployed on AWS ECS Fargate.

## Overview

The infrastructure creates a complete AWS environment including:
- SSL/TLS certificate management
- DNS configuration
- Container registry
- ECS Fargate cluster
- DynamoDB tables
- VPC networking
- Load balancer
- IAM roles and policies
- CloudWatch logging

## Provider Configuration

```hcl
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```
- Configures the AWS provider with the region specified in variables
- Includes random provider for secure secret generation
- All resources will be created in this region

## SSL Certificate Management

### ACM Certificate
```hcl
resource "aws_acm_certificate" "shopmate" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}
```
- Creates an SSL certificate for the domain
- Uses DNS validation (requires Route53 zone)
- `create_before_destroy` ensures zero-downtime certificate renewal

### Certificate Validation
```hcl
resource "aws_acm_certificate_validation" "shopmate" {
  certificate_arn         = aws_acm_certificate.shopmate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
```
- Waits for certificate validation to complete
- Depends on DNS validation records being created

## DNS Configuration (Route53)

### Conditional Zone Creation
```hcl
data "aws_route53_zone" "selected" {
  count = var.create_route53_zone ? 0 : 1
  name  = var.route53_zone_name
}

resource "aws_route53_zone" "primary" {
  count = var.create_route53_zone ? 1 : 0
  name  = var.route53_zone_name
}
```
- Uses ternary operation to conditionally create or use existing Route53 zone
- If `create_route53_zone = true`: Creates new zone
- If `create_route53_zone = false`: Uses existing zone

### Zone ID Resolution
```hcl
locals {
  route53_zone_id = var.create_route53_zone ? aws_route53_zone.primary[0].zone_id : data.aws_route53_zone.selected[0].zone_id
}
```
- Local value that resolves to the correct zone ID regardless of creation method

### Certificate Validation Records
```hcl
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.shopmate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  # ... record configuration
}
```
- Creates DNS records required for certificate validation
- Uses `for_each` to handle multiple domain validation options

### Application DNS Record
```hcl
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
```
- Creates A record pointing domain to load balancer
- Uses alias record for better performance and cost

## Container Registry

### ECR Repository
```hcl
resource "aws_ecr_repository" "shopmate" {
  name                 = "shopmate"
  image_tag_mutability = "MUTABLE"
}
```
- Creates ECR repository for Docker images
- `MUTABLE` allows overwriting tags (useful for development)
- **Shared across environments**: All environments (dev/uat/prod) use the same repository

### ECR Lifecycle Policy
```hcl
resource "aws_ecr_lifecycle_policy" "shopmate" {
  repository = aws_ecr_repository.shopmate.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
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
```
- **Automatic cleanup**: Keeps only the last 10 tagged images
- **Untagged cleanup**: Removes untagged images after 1 day
- **Cost optimization**: Prevents unlimited image accumulation
- **Tag prefix support**: Handles versioned tags (v1.0.0) and latest

## ECS Configuration

### ECS Cluster
```hcl
resource "aws_ecs_cluster" "shopmate" {
  name = "shopmate-${var.environment}"
}
```
- Creates ECS cluster with environment-specific naming

### CloudWatch Log Group
```hcl
resource "aws_cloudwatch_log_group" "shopmate" {
  name = "/ecs/shopmate-${var.environment}"
  retention_in_days = 30
}
```
- Creates log group for container logs
- 30-day retention to manage costs

## Security - Session Secret Management

### Random Secret Generation
```hcl
resource "random_password" "session_secret" {
  length  = 64
  special = true
}
```
- Generates cryptographically secure 64-character random password
- Includes special characters for enhanced security
- Unique per environment deployment

### AWS Secrets Manager
```hcl
resource "aws_secretsmanager_secret" "session_secret" {
  name = "shopmate-session-secret-${var.environment}"
  description = "Session secret for ShopMate ${var.environment}"
}

resource "aws_secretsmanager_secret_version" "session_secret" {
  secret_id     = aws_secretsmanager_secret.session_secret.id
  secret_string = random_password.session_secret.result
}
```
- Stores the generated secret securely in AWS Secrets Manager
- Environment-specific secret naming
- Encrypted at rest and in transit

### Secrets Manager IAM Policy
```hcl
resource "aws_iam_policy" "secrets_access" {
  name = "shopmate-secrets-access-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["secretsmanager:GetSecretValue"]
      Effect = "Allow"
      Resource = aws_secretsmanager_secret.session_secret.arn
    }]
  })
}
```
- Grants ECS tasks permission to retrieve secrets
- Scoped to only the application's session secret
- Attached to the ECS task role

## Database Layer (DynamoDB)

### Products Table
```hcl
resource "aws_dynamodb_table" "products" {
  name           = "shopmate-products-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "N"  # Number
  }
}
```
- Stores product catalog
- Pay-per-request billing for cost optimization
- Primary key: `id` (Number)

### Orders Table
```hcl
resource "aws_dynamodb_table" "orders" {
  name           = "shopmate-orders-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "N"
  }
}
```
- Stores customer orders
- Same structure as products table

### Carts Table
```hcl
resource "aws_dynamodb_table" "carts" {
  name           = "shopmate-carts-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  
  attribute {
    name = "userId"
    type = "S"  # String
  }
}
```
- Stores shopping cart data
- Primary key: `userId` (String)

## IAM Roles and Policies

### ECS Task Execution Role
```hcl
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "shopmate-execution-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}
```
- Role for ECS to pull images and write logs
- Attached to AWS managed policy: `AmazonECSTaskExecutionRolePolicy`

### ECS Task Role (Application Permissions)
```hcl
resource "aws_iam_role" "ecs_task_role" {
  name = "shopmate-task-role-${var.environment}"
  # ... assume role policy
}
```
- Role for application to access AWS services
- Used by the running container

### DynamoDB Access Policy
```hcl
resource "aws_iam_policy" "dynamodb_access" {
  name = "shopmate-dynamodb-access-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ]
      Effect = "Allow"
      Resource = [
        aws_dynamodb_table.products.arn,
        aws_dynamodb_table.orders.arn,
        aws_dynamodb_table.carts.arn
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_role_dynamodb" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

resource "aws_iam_role_policy_attachment" "task_role_secrets" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}
```
- Grants full CRUD access to DynamoDB tables
- Scoped to only the application's tables
- Includes Secrets Manager access for session secrets

## Networking (VPC)

### VPC
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```
- Creates isolated network environment
- DNS support enabled for service discovery

### Public Subnets
```hcl
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = true
}
```
- Two subnets in different AZs for high availability
- Public subnets for load balancer and Fargate tasks
- Auto-assign public IPs

### Internet Gateway
```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
```
- Provides internet access to VPC

### Route Table
```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
```
- Routes all traffic (0.0.0.0/0) to internet gateway
- Associated with both public subnets

## Security

### Security Group
```hcl
resource "aws_security_group" "shopmate" {
  name        = "shopmate-sg-${var.environment}"
  description = "Allow inbound traffic to ShopMate"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
```
- Allows inbound traffic on ports 3000 (app), 80 (HTTP), 443 (HTTPS)
- Allows all outbound traffic
- Applied to both load balancer and ECS tasks

## ECS Task Definition

```hcl
resource "aws_ecs_task_definition" "shopmate" {
  family                   = "shopmate-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "shopmate"
    image     = "${aws_ecr_repository.shopmate.repository_url}:latest"
    essential = true
    
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]
    
    secrets = [
      {
        name      = "SESSION_SECRET"
        valueFrom = aws_secretsmanager_secret.session_secret.arn
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
        name  = "AWS_REGION"
        value = var.aws_region
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
  }])
}
```

### Key Components:
- **Resource Allocation**: 256 CPU units, 512MB memory
- **Networking**: `awsvpc` mode for dedicated ENI
- **Container Image**: References ECR repository
- **Secrets**: SESSION_SECRET retrieved from AWS Secrets Manager at runtime
- **Environment Variables**: 
  - Application configuration (NODE_ENV, PORT)
  - DynamoDB table names for data access
  - AWS region for SDK configuration
- **Logging**: CloudWatch logs with structured naming

## Load Balancer

```hcl
resource "aws_lb" "shopmate" {
  name               = "shopmate-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.shopmate.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}
```
- Application Load Balancer (Layer 7)
- Internet-facing for public access
- Deployed across multiple AZs for high availability
- Uses the security group for traffic control

## State Management

### S3 Backend Configuration
```hcl
terraform {
  backend "s3" {
    bucket  = "sctp-ce10-tfstate"
    key     = "shopmate/{environment}/terraform.tfstate"
    region  = "ap-southeast-1"
    encrypt = true
  }
}
```
- **Remote state storage**: Terraform state stored in S3 bucket
- **Environment isolation**: Separate state files per environment
  - Dev: `shopmate/dev/terraform.tfstate`
  - UAT: `shopmate/uat/terraform.tfstate`
  - Prod: `shopmate/prod/terraform.tfstate`
- **Encryption**: State files encrypted at rest
- **Shared access**: Multiple developers can access same state

## Environment Variables Explained

The application receives these environment variables and secrets:

**Environment Variables:**
1. **NODE_ENV**: Sets application environment (dev/uat/prod)
2. **PORT**: Application listening port (3000)
3. **PRODUCTS_TABLE**: DynamoDB products table name
4. **ORDERS_TABLE**: DynamoDB orders table name  
5. **CARTS_TABLE**: DynamoDB carts table name
6. **AWS_REGION**: AWS region for SDK configuration

**Secrets (from AWS Secrets Manager):**
1. **SESSION_SECRET**: Cryptographically secure session encryption key

These are consumed by:
- `app.js`: NODE_ENV, PORT, SESSION_SECRET
- `utils/dynamodb.js`: All table names and AWS_REGION

## Resource Dependencies

The infrastructure has these key dependencies:

1. **Certificate** → **Route53 Records** → **Certificate Validation**
2. **VPC** → **Subnets** → **Internet Gateway** → **Route Tables**
3. **ECR Repository** → **Task Definition** → **ECS Service**
4. **DynamoDB Tables** → **IAM Policy** → **Task Role**
5. **Load Balancer** → **Target Group** → **ECS Service**

## Cost Optimization Features

1. **DynamoDB**: Pay-per-request billing
2. **Fargate**: Pay only for running tasks
3. **CloudWatch**: 30-day log retention
4. **ECR**: Lifecycle policies automatically clean up old images
5. **Load Balancer**: Single ALB serves all traffic
6. **Shared ECR**: Single repository used across all environments
7. **S3 State**: Centralized state storage reduces duplication

## Security Best Practices

1. **Least Privilege**: IAM roles have minimal required permissions
2. **Network Isolation**: VPC with security groups
3. **Encryption**: SSL/TLS certificates for HTTPS
4. **Secret Management**: Session secrets stored in AWS Secrets Manager
5. **Secure Secret Generation**: Cryptographically secure random secrets per environment
6. **Runtime Secret Injection**: Secrets never stored in plain text in configurations
7. **Logging**: All container logs sent to CloudWatch
8. **Resource Tagging**: Environment-based resource naming

## Deployment Architecture

### Image Promotion Strategy
```
Dev Environment:
├── Build Docker image (commit SHA + latest)
├── Push to shared ECR repository
└── Deploy to dev ECS cluster

Staging Environment:
├── Reuse image from dev (no rebuild)
└── Deploy to uat ECS cluster

Production Environment:
├── Reuse image from dev (no rebuild)
└── Deploy to prod ECS cluster
```

### Benefits:
- **Faster deployments**: No rebuild time for staging/production
- **Consistent artifacts**: Same tested image across environments
- **Cost efficiency**: Reduced CI/CD build minutes
- **Shared resources**: ECR repository used by all environments

### Environment-Specific Resources:
- **VPC and networking**: Isolated per environment
- **ECS clusters**: Separate clusters per environment
- **DynamoDB tables**: Environment-specific naming
- **IAM roles**: Environment-specific permissions
- **Load balancers**: Separate ALBs per environment
- **Domains**: Environment-specific subdomains

### Shared Resources:
- **ECR repository**: Single `shopmate` repository
- **S3 state bucket**: Shared with environment-specific keys
- **Route53 zone**: Shared parent zone (`sctp-sandbox.com`)

This infrastructure provides a production-ready, scalable, and secure foundation for the ShopMate e-commerce application with optimized CI/CD workflows and cost-effective resource sharing.