terraform {
  backend "s3" {
    bucket  = "sctp-ce10-tfstate"
    key     = "shopmate/terraform.tfstate"
    region  = "ap-southeast-1"
    encrypt = true
  }
}