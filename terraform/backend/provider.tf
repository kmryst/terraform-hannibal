
# terraform/backend/provider.tf

# AWSやGCP、Azureなど、どのクラウドサービスとやり取りするかを定義します
# 認証情報（リージョン、プロファイルなど）やバージョン指定、エイリアス（複数プロバイダー利用時）などもここに書きます


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.8.0" # ECS Native Blue/Green対応版
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}
