# セットアップガイド - NestJS Hannibal 3

## � セットアップ概要

このプロジェクトは **Terraform + GitHub Actions** で完全自動化されています。
手動セットアップは **IAM設定 → Terraform State初期化 → GitHub Secrets登録** の3ステップのみ。

---

## 🔐 ステップ1: IAM設定（初回のみ）

### 1-1. IAM User作成

```bash
# AWS CLIで基盤IAMを作成
aws iam create-user --user-name hannibal
aws iam create-user --user-name hannibal-cicd
```

### 1-2. Permission Boundary適用

```bash
cd terraform/foundation
terraform init
terraform apply  # IAMポリシー・ロール作成
```

**作成されるリソース:**
- `HannibalDeveloperRole-Dev` (手動操作用)
- `HannibalCICDRole-Dev` (GitHub Actions用)
- `HannibalCICDBoundary` (Permission Boundary)

### 1-3. Access Key発行

```bash
# GitHub Actions用の認証情報
aws iam create-access-key --user-name hannibal-cicd
```

**出力例:**
```json
{
  "AccessKey": {
    "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
    "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  }
}
```

---

## 🗄️ ステップ2: Terraform State初期化（初回のみ）

### 2-1. S3バケット + DynamoDB作成

```bash
cd terraform/foundation
terraform init
terraform apply

# 作成されるリソース:
# - S3: nestjs-hannibal-3-terraform-state (State保存)
# - DynamoDB: terraform-state-lock (Lock管理)
```

### 2-2. Backend設定確認

**ファイル構造:**
```
terraform/
├── foundation/          # 基盤（State管理自体はlocal）
│   └── main.tf
└── environments/dev/    # アプリ環境（S3バックエンド利用）
    └── main.tf
```

**dev環境の設定例** (`terraform/environments/dev/main.tf`):
```hcl
terraform {
  backend "s3" {
    bucket         = "nestjs-hannibal-3-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### 2-3. 初期化実行

```bash
cd terraform/environments/dev
terraform init  # S3バックエンド初期化
terraform plan  # 変更プレビュー
```

---

## 🔑 ステップ3: GitHub Secrets登録

### 3-1. 必須Secrets一覧

| Secret名 | 説明 | 取得方法 |
|---------|------|---------|
| `AWS_ACCESS_KEY_ID` | hannibal-cicd のAccess Key | ステップ1-3で取得 |
| `AWS_SECRET_ACCESS_KEY` | hannibal-cicd のSecret Key | ステップ1-3で取得 |
| `AWS_REGION` | デプロイ先リージョン | `ap-northeast-1` |
| `DATABASE_URL` | PostgreSQL接続文字列 | 初回デプロイ後に設定 |
| `CLIENT_URL` | Frontend URL | `https://hamilcar-hannibal.click` |

### 3-2. 登録方法（GitHub CLI推奨）

```powershell
# PowerShellでの登録例
gh secret set AWS_ACCESS_KEY_ID -b "AKIAIOSFODNN7EXAMPLE"
gh secret set AWS_SECRET_ACCESS_KEY -b "wJalrXUtnFEMI/K7MDENG/..."
gh secret set AWS_REGION -b "ap-northeast-1"
gh secret set CLIENT_URL -b "https://hamilcar-hannibal.click"
```

**DATABASE_URL は初回デプロイ後に追加:**
```powershell
# RDS作成後
gh secret set DATABASE_URL -b "postgresql://hannibal:PASSWORD@xxx.rds.amazonaws.com:5432/hannibal"
```

---

## 🚀 ステップ4: 初回デプロイ

### 4-1. GitHub Actionsで実行

```bash
# WebUIで手動実行: .github/workflows/deploy.yml
# 入力パラメータ:
#   deployment_mode: provisioning
#   environment: dev
```

**所要時間**: 約15分

### 4-2. デプロイフロー

```
1. Terraform Apply (VPC/ECS/RDS/ALB/CloudFront作成)
   ↓
2. Docker Build + ECR Push
   ↓
3. ECS Task Definition作成
   ↓
4. ECS Service起動（Blue環境）
   ↓
5. CloudFront DNS設定（hamilcar-hannibal.click）
```

### 4-3. デプロイ確認

```bash
# ALB Health Check
aws elbv2 describe-target-health \
  --target-group-arn <ARN>

# ECS Task状態確認
aws ecs describe-tasks \
  --cluster nestjs-hannibal-3-cluster \
  --tasks <TASK_ARN>
```

---

## 🔧 ローカル開発環境セットアップ

### Backend (NestJS)

```bash
# 依存関係インストール
npm ci

# 環境変数設定
cp .env.example .env
# DATABASE_URL=postgresql://user:pass@localhost:5432/hannibal
# NODE_ENV=development
# DEV_CLIENT_URL_LOCAL=http://localhost:5173

# 開発サーバー起動
npm run start:dev  # http://localhost:3000/graphql
```

### Frontend (React + Vite)

```bash
cd client
npm ci

# 環境変数設定
echo "VITE_GRAPHQL_ENDPOINT=http://localhost:3000/graphql" > .env

npm run dev  # http://localhost:5173
```

### Infrastructure (Terraform)

```bash
cd terraform/environments/dev

# AssumeRole設定（PowerShell）
$env:AWS_PROFILE = "hannibal-dev"

# 変更プレビュー
terraform plan

# リソース作成
terraform apply
```

---

## 📋 関連ドキュメント

- **[CONTRIBUTING.md](../../CONTRIBUTING.md)** - Issue駆動開発フロー（必読）
- **[docs/architecture/](../architecture/)** - システム設計詳細
- **[docs/deployment/](../deployment/)** - Blue/Green・Canaryデプロイ手順
- **[docs/operations/](../operations/)** - 日常運用・監視・トラブルシュート
- **[docs/troubleshooting/](../troubleshooting/)** - よくある問題と解決方法

---

## 🚨 トラブルシューティング

### Terraform State Lock エラー

```bash
# 原因: 別の操作が実行中 or 異常終了
# 解決: Lock解除（他の操作がないことを確認）
terraform force-unlock <LOCK_ID>
```

### ECS Task起動失敗

```bash
# CloudWatch Logs確認
aws logs tail /ecs/nestjs-hannibal-3 --follow

# 原因: DATABASE_URL環境変数未設定
# 解決: GitHub Secretsに追加 → 再デプロイ
```

### Backend初期化エラー

```bash
# エラー: "Backend initialization required"
# 解決: terraform init を再実行
cd terraform/environments/dev
terraform init -reconfigure
```

---

**最終更新**: 2025年10月12日  
**セットアップ所要時間**: 初回約2時間（IAM設定30分 + Terraform実行15分 + 動作確認15分）