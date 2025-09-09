/**
 * Terraform プロバイダー設定ファイル
 * 
 * ハンニバルのアルプス越えルートアプリケーションの
 * AWS インフラストラクチャ管理用プロバイダー設定。
 * 
 * 設定内容:
 * - AWS プロバイダーのバージョン管理
 * - リージョン設定 (ap-northeast-1 固定)
 * - Terraform コアバージョン制約
 * - プロバイダーの互換性管理
 */

# Terraform コア設定と必要プロバイダーの定義
terraform {
  # AWS プロバイダーのバージョン制約
  # 6.8.0 以上のマイナーバージョンを許可、メジャーバージョンアップは防止
  required_providers {
    aws = {
      source  = "hashicorp/aws"  # HashiCorp 公式 AWS プロバイダー
      version = "~> 6.8.0"        # 6.8.x 系列の最新版を使用
    }
  }
  # Terraform コアの最低バージョン要件
  # 1.0 以上で安定した HCL 構文と機能を保証
  required_version = ">= 1.0"
}

# AWS プロバイダーの設定
# 認証情報は環境変数や AWS CLI プロファイルから自動取得
provider "aws" {
  region = var.aws_region  # リージョンは variables.tf で定義された値を使用
  
  # タグ付けのデフォルトルール (全リソースに自動適用)
  default_tags {
    tags = {
      Project     = "nestjs-hannibal-3"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "terraform-hannibal"
    }
  }
}
