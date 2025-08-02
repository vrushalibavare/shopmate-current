terraform {
  backend "s3" {
    bucket  = "sctp-ce10-tfstate"
    key     = "shopmate/uat/terraform.tfstate"
    region  = "ap-southeast-1"
    encrypt = true
  }
}

module "shopmate" {
  source = "../../"

  environment         = "uat"
  aws_region          = "ap-southeast-1"
  app_count           = 2
  domain_name         = "shopmate.uat.sctp-sandbox.com"
  route53_zone_name   = "sctp-sandbox.com"
  create_route53_zone = false # Using existing zone
}