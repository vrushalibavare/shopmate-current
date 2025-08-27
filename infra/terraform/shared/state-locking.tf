# ============================================================================
# TERRAFORM STATE LOCKING
# ============================================================================
# DynamoDB table for Terraform state locking to prevent concurrent deployments

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Locks"
    Environment = "shared"
    Purpose     = "State locking for all environments"
  }
}