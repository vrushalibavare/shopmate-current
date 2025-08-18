terraform {
  backend "s3" {
    bucket  = "sctp-ce10-tfstate"
    key     = "shopmate/prod/terraform.tfstate"
    region  = "ap-southeast-1"
    encrypt = true
  }
}

module "shopmate" {
  source = "../../"

  environment = "prod"
  aws_region  = "ap-southeast-1"
  app_count   = 3

  domain_name         = "shopmate.prod.sctp-sandbox.com"
  route53_zone_name   = "sctp-sandbox.com"
  create_route53_zone = false # Using existing zone
}