# terraform/foundation/dynamodb.tf
# 基盤DynamoDBリソース（手動作成・永続管理）
# AWS Professional設計: Infrastructure as Code + 永続管理

# --- Terraform State Lock管理（移行期間用） ---
# DynamoDBテーブル（手動作成・移行期間中は永続管理）
# 現在の正は S3 backend の use_lockfile = true。
# このテーブルは DynamoDB-based locking から S3 lockfile へ移行する間だけ併用する。
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
# - Purpose: Terraform同時実行ロック制御（legacy / migration）
# - Status: 手動管理・destroy対象外。S3 lockfile 安定後に削除可否を判断

# --- 実装後の管理方針 ---
# 1. 手動でDynamoDBテーブル作成
# 2. backend.tfでuse_lockfile=trueとdynamodb_tableを併用
# 3. 移行期間中は保持し、安定後にdynamodb_tableと関連IAM権限/docsを削除
# 4. コードは再現性・ドキュメント用に保持

# --- 連携設定例 ---
# terraform {
#   backend "s3" {
#     bucket         = "nestjs-hannibal-3-terraform-state"
#     key            = "backend/terraform.tfstate"
#     region         = "ap-northeast-1"
#     use_lockfile   = true
#     dynamodb_table = "terraform-state-lock"  # Legacy lock during migration
#     encrypt        = true
#   }
# }

# --- 設計方針 ---
# - 基盤リソース: 手動管理・永続化
# - アプリケーションリソース: Terraform管理
# - 同時実行制御: S3 lockfile（DynamoDB State Lock は移行期間中のみ併用）
# - 監査性: CloudTrail + Athena分析
