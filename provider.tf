provider "aws" {
  #region  = local.aws_region
  #profile = local.aws_profile
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
