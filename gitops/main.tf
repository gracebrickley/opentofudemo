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
    "opentofu-day-2025-primary-data-1",
    "opentofu-day-2025-backups",
    "opentofu-day-2025-logs",
    "opentofu-day-2025-artifacts",
    "opentofu-day-2025-temp-storage"
  ]
}

resource "aws_s3_bucket" "opentofu-day-2025-buckets" {
  for_each = toset(local.s3_bucket_names)
  bucket = each.value
  tags = {
    Name = each.value
  }
}