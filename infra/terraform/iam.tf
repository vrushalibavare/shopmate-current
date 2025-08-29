# ============================================================================
# IAM ROLES & POLICIES + SECRETS MANAGEMENT
# ============================================================================
# Identity and Access Management for ECS tasks and AWS service integration
#
# NOTE: GitHub Actions deployment permissions (including Parameter Store access
# for secure backend configuration) are defined in shared/github-oidc.tf
#
# CREATION FLOW:
# 1. Secrets Generation & Storage (Application Security)
# 2. IAM Roles (Identity Definitions)
# 3. IAM Policies (Permission Definitions)
# 4. Policy Attachments (Connect Roles to Permissions)

# ============================================================================
# 1. IAM ROLES - Identity Definitions
# ============================================================================

# ECS Task Execution Role - Used by ECS service to start containers
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "shopmate-execution-role-${var.environment}"

  # Trust policy - allows ECS service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com" # Only ECS can assume this role
        }
      }
    ]
  })
}

# ECS Task Role - Used by application containers at runtime
resource "aws_iam_role" "ecs_task_role" {
  name = "shopmate-task-role-${var.environment}"

  # Trust policy - allows ECS tasks to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com" # Only ECS tasks can assume this role
        }
      }
    ]
  })
}

# ============================================================================
# 2. IAM POLICIES - Permission Definitions
# ============================================================================

# DynamoDB access policy - Application data operations
resource "aws_iam_policy" "dynamodb_access" {
  name        = "shopmate-dynamodb-access-${var.environment}"
  description = "Allow CRUD operations on ShopMate DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:BatchGetItem",   # Batch read operations
          "dynamodb:GetItem",        # Single item read
          "dynamodb:Query",          # Query operations
          "dynamodb:Scan",           # Scan operations
          "dynamodb:BatchWriteItem", # Batch write operations
          "dynamodb:PutItem",        # Create/update item
          "dynamodb:UpdateItem",     # Update item
          "dynamodb:DeleteItem",     # Delete item
          "dynamodb:DescribeTable"   # Table metadata
        ]
        Effect = "Allow"
        Resource = [
          aws_dynamodb_table.products.arn, # From storage.tf
          aws_dynamodb_table.orders.arn,
          aws_dynamodb_table.carts.arn,
          aws_dynamodb_table.sessions.arn
        ]
      }
    ]
  })
}

# Secrets Manager access policy - Application secrets
resource "aws_iam_policy" "secrets_access" {
  name        = "shopmate-secrets-access-${var.environment}"
  description = "Allow reading ShopMate application secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue" # Read secret values
        ]
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret.session_secret.arn,
          aws_secretsmanager_secret.grafana_password.arn
        ]
      }
    ]
  })
}

# CloudWatch access policy - Monitoring and logging
resource "aws_iam_policy" "cloudwatch_read" {
  name        = "shopmate-cloudwatch-read-${var.environment}"
  description = "Allow read access to CloudWatch metrics and logs for Grafana"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:GetMetricStatistics", # Read metric data
          "cloudwatch:ListMetrics",         # List available metrics
          "cloudwatch:GetMetricData",       # Batch metric queries
          "logs:DescribeLogGroups",         # List log groups
          "logs:DescribeLogStreams",        # List log streams
          "logs:GetLogEvents",              # Read log events
          "logs:StartQuery",                # CloudWatch Insights queries
          "logs:StopQuery",                 # Stop running queries
          "logs:GetQueryResults"            # Get query results
        ]
        Effect   = "Allow"
        Resource = "*" # CloudWatch requires wildcard for some operations
      }
    ]
  })
}

# ECS Exec access policy - All environments (security controlled by container image)
resource "aws_iam_policy" "ecs_exec_access" {
  name        = "shopmate-ecs-exec-access-${var.environment}"
  description = "Allow ECS Exec access for debugging (security controlled by container capabilities)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# 3. POLICY ATTACHMENTS - Connect Roles to Permissions
# ============================================================================

# Attach AWS managed policy to execution role (ECR, CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach secrets access to execution role (for container startup)
resource "aws_iam_role_policy_attachment" "execution_role_secrets" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# Attach DynamoDB access to task role (for application runtime)
resource "aws_iam_role_policy_attachment" "task_role_dynamodb" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# Attach secrets access to task role (for application runtime)
resource "aws_iam_role_policy_attachment" "task_role_secrets" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# Attach CloudWatch access to task role (for Grafana monitoring)
resource "aws_iam_role_policy_attachment" "task_role_cloudwatch" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.cloudwatch_read.arn
}

# Attach ECS Exec access to task role (all environments)
resource "aws_iam_role_policy_attachment" "task_role_ecs_exec" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_exec_access.arn
}