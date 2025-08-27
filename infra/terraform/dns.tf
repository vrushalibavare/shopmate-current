# ============================================================================
# SSL/TLS CERTIFICATE & DNS MANAGEMENT
# ============================================================================
# Manages SSL certificates and DNS records for secure HTTPS access
#
# CREATION FLOW:
# 1. Route53 Zone (DNS Authority)
# 2. SSL Certificate Request (ACM)
# 3. DNS Validation Records (Prove Domain Ownership)
# 4. Certificate Validation (Wait for Validation)
# 5. Application DNS Record (Point Domain to Load Balancer)

# ============================================================================
# 1. ROUTE53 ZONE - DNS Authority
# ============================================================================

# Use existing Route53 zone (if available)
data "aws_route53_zone" "selected" {
  count = var.create_route53_zone ? 0 : 1
  name  = var.route53_zone_name
}

# Create new Route53 zone (if needed)
resource "aws_route53_zone" "primary" {
  count = var.create_route53_zone ? 1 : 0
  name  = var.route53_zone_name
}

# Local value to reference the correct zone ID
locals {
  route53_zone_id = var.create_route53_zone ? aws_route53_zone.primary[0].zone_id : data.aws_route53_zone.selected[0].zone_id
}

# ============================================================================
# 2. SSL CERTIFICATE REQUEST - HTTPS Security
# ============================================================================

# SSL Certificate from AWS Certificate Manager
resource "aws_acm_certificate" "shopmate" {
  domain_name       = var.domain_name # e.g., shopmate.dev.sctp-sandbox.com
  validation_method = "DNS"           # Validate via DNS records

  lifecycle {
    create_before_destroy = true # Prevent downtime during certificate renewal
  }
}

# ============================================================================
# 3. DNS VALIDATION RECORDS - Prove Domain Ownership
# ============================================================================

# DNS records to validate certificate ownership
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.shopmate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name  # ACM-generated validation record name
      record = dvo.resource_record_value # ACM-generated validation record value
      type   = dvo.resource_record_type  # Usually CNAME
    }
  }

  allow_overwrite = true # Allow Terraform to manage these records
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60 # Short TTL for faster validation
  type            = each.value.type
  zone_id         = local.route53_zone_id
}

# ============================================================================
# 4. CERTIFICATE VALIDATION - Wait for Validation
# ============================================================================

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "shopmate" {
  certificate_arn         = aws_acm_certificate.shopmate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  # This resource blocks until validation is complete
  # Required before ALB listener can use the certificate
}

# ============================================================================
# 5. APPLICATION DNS RECORD - Point Domain to Load Balancer
# ============================================================================

# DNS A record pointing domain to load balancer
resource "aws_route53_record" "shopmate" {
  zone_id = local.route53_zone_id
  name    = var.domain_name
  type    = "A"

  # Alias record (no IP address, points to AWS resource)
  alias {
    name                   = aws_lb.shopmate.dns_name # From networking.tf
    zone_id                = aws_lb.shopmate.zone_id  # ALB's Route53 zone
    evaluate_target_health = true                     # Health check integration
  }
}