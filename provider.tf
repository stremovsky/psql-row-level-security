variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region = var.region
  profile = "dev"
}

data "aws_caller_identity" "current" {}
