# ============================================================================
# GITHUB OIDC AUTHENTICATION
# ============================================================================
# IAM role for GitHub Actions to deploy infrastructure using OIDC

# Reference existing GitHub OIDC provider
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::255945442255:oidc-provider/token.actions.githubusercontent.com"
}

# IAM role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "shopmate-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:*:*"
          }
        }
      }
    ]
  })
}

# IAM policy for deployment permissions
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "shopmate-deployment-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:*",
          "ecs:*",
          "dynamodb:*",
          "logs:*",
          "iam:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "route53:*",
          "acm:*",
          "secretsmanager:*",
          "cloudwatch:*",
          "s3:*",
          "application-autoscaling:*"
        ]
        Resource = "*"
      }
    ]
  })
}

