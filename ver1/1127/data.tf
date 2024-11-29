// pre // 
data "http" "ipinfo" {
  url = "https://ipinfo.io"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
locals {
  use_az = [
    "${data.aws_region.current.name}a",
    "${data.aws_region.current.name}c",
  ]
  az_short = [
    "a", "c",
  ]
}

data "hcp_vault_secrets_app" "aws_app" {
  app_name = "AWS"
}


data "aws_ami" "al-recent" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-20*-x86_64"]
  }
  owners = ["137112412989"]
}