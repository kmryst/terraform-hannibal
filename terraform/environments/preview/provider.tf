terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.8.0"
    }
  }

  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project         = local.project_name
      Environment     = local.environment_name
      EnvironmentType = local.environment_type
      PRNumber        = tostring(var.pr_number)
      ManagedBy       = "Terraform"
      Repository      = "terraform-hannibal"
    }
  }
}
