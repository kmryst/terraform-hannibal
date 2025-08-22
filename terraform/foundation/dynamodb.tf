# terraform/foundation/dynamodb.tf
# 基盤DynamoDBリソース（手動作成・永続管理）
# AWS Professional設計: Infrastructure as Code + 永続管理

# --- Terraform State Lock管理 ---
# DynamoDBテーブル（手動作成・永続管理）
# 作成コマンド:
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region ap-northeast-1

# テーブル詳細:
# - Table Name: terraform-state-lock
# - Primary Key: LockID (String)
# - Billing Mode: PAY_PER_REQUEST
# - Purpose: Terraform同時実行ロック制御
# - Status: 手動管理・destroy対象外

# --- 実装後の管理方針 ---
# 1. 手動でDynamoDBテーブル作成
# 2. backend.tfでdynamodb_table設定追加
# 3. 以降は永続保持・手動管理
# 4. コードは再現性・ドキュメント用に保持

# --- 連携設定例 ---
# terraform {
#   backend "s3" {
#     bucket         = "nestjs-hannibal-3-terraform-state"
#     key            = "backend/terraform.tfstate"
#     region         = "ap-northeast-1"
#     dynamodb_table = "terraform-state-lock"  # ← この設定が必要
#     encrypt        = true
#   }
# }

# --- 企業レベル設計原則 ---
# Netflix/Airbnb/Spotify標準パターン:
# - 基盤リソース: 手動管理・永続化
# - アプリケーションリソース: Terraform管理
# - 同時実行制御: DynamoDB State Lock
# - 監査性: CloudTrail + Athena分析