terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket = "opentofu-day-2025-statefile"
    key = "terraform.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

locals {
  s3_bucket_names = [
    "tofu-primary-data",
    "tofu-backups",
    "opentofu-day-2025-logs",
    "tofu-artifacts",
    "tofu-temp-storage"
  ]
}

resource "aws_s3_bucket" "tofu_buckets" {
  for_each = toset(local.s3_bucket_names)
  bucket = each.value
  tags = {
    Name = each.value
  }
}