terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project     = "nestjs-hannibal-3"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "terraform-hannibal"
    }
  }
}
