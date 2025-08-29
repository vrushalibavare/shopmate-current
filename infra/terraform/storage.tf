# ============================================================================
# CONTAINER REGISTRY & DATABASE LAYER
# ============================================================================
# ECR repository reference and DynamoDB tables for application data storage


# ============================================================================
# 3. DYNAMODB TABLES - Application Data Storage
# ============================================================================

# Products table - E-commerce product catalog
resource "aws_dynamodb_table" "products" {
  name         = "shopmate-products-${var.environment}"
  billing_mode = "PAY_PER_REQUEST" # Serverless billing
  hash_key     = "id"              # Primary key

  attribute {
    name = "id"
    type = "N" # Number (product ID)
  }
}

# Orders table - Customer order history
resource "aws_dynamodb_table" "orders" {
  name         = "shopmate-orders-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # String (order UUID)
  }
}

# Carts table - Shopping cart data (stateless architecture)
resource "aws_dynamodb_table" "carts" {
  name         = "shopmate-carts-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S" # String (user identifier)
  }
}

# Sessions table - User sessions (enables stateless containers)
resource "aws_dynamodb_table" "sessions" {
  name         = "shopmate-sessions-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # String (session ID)
  }

  # TTL for automatic session cleanup
  ttl {
    attribute_name = "expires" # Session expiration timestamp
    enabled        = true      # Automatic cleanup
  }
}