# terraform/backend/provider.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # バージョンは適宜最新のものに更新
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}
