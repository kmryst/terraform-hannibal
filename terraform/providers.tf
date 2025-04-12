# C:\code\javascript\nestjs-hannibal-3\terraform\providers.tf

provider "aws" {
  region = "ap-northeast-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # --- バージョン制約を更新 ---
      version = "~> 5.0" # より新しい安定バージョンを指定
    }
  }
  # required_version は Terraform CLI のバージョン。必要に応じて設定。
  # required_version = ">= 1.0.0"
}
