
# terraform/backend/provider.tf

# AWSやGCP、Azureなど、どのクラウドサービスとやり取りするかを定義します
# 認証情報（リージョン、プロファイルなど）やバージョン指定、エイリアス（複数プロバイダー利用時）などもここに書きます


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
