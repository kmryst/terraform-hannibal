# セットアップガイド - NestJS Hannibal 3

## セットアップ概要

このプロジェクトは **Terraform + GitHub Actions** で完全自動化されています。
手動セットアップは **IAM/OIDC設定 → Terraform State初期化** の2ステップのみ。

GitHub Actions から AWS への認証は **OIDC（OpenID Connect）** を使います。
長期 Access Key は不要です。

---

## ステップ1: IAM/OIDC設定（初回のみ）

### 1-1. IAM User作成

開発者手動操作用のユーザーを作成します（GitHub Actions用は不要）。

```bash
aws iam create-user --user-name hannibal
```

### 1-2. foundation Terraform apply

```bash
cd terraform/foundation
terraform init
terraform apply
```

**作成されるリソース:**
- `aws_iam_openid_connect_provider` — GitHub Actions OIDC プロバイダー
- `HannibalDeveloperRole-Dev` — 日常開発・アプリ運用用 Role
- `HannibalCICDRole-Dev` — deploy/destroy workflow 用 Role（OIDC trust）
- `HannibalPRPlanRole-Dev` — PR terraform plan 用 Role（OIDC trust・read-only）
- `HannibalCICDBoundary` / `HannibalECSBoundary` — Permission Boundary
- Athena Workgroup / Database / Budget アラーム 等

foundation apply 後、GitHub Actions の deploy/destroy は OIDC で `HannibalCICDRole-Dev` を
AssumeRoleWithWebIdentity します。Access Key の発行・登録は不要です。
初回構築後に `terraform/foundation` を更新する場合は `HannibalFoundationRole-Dev` を assume し、
`HannibalDeveloperRole-Dev` では foundation apply を実行しません。

---

## ステップ2: Terraform State初期化（初回のみ）

### 2-1. S3バケット + DynamoDB作成

Terraform state 用のバックエンドリソースを手動で作成します。

```bash
aws s3 mb s3://nestjs-hannibal-3-terraform-state --region ap-northeast-1
aws s3api put-bucket-versioning \
  --bucket nestjs-hannibal-3-terraform-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1
```

### 2-2. Backend設定確認

```
terraform/
├── foundation/          # 基盤（IAM/OIDC/Athena等。backend は local）
└── environments/dev/    # アプリ環境（S3 backend）
```

`terraform/environments/dev/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "nestjs-hannibal-3-terraform-state"
    key            = "environments/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### 2-3. 初期化実行

```bash
cd terraform/environments/dev
terraform init
```

---

## ステップ3: GitHub Secrets

AWS 認証は OIDC のため、**長期 Access Key の登録は不要**です。

現在 GitHub Actions が参照する Secret はありません（`GITHUB_TOKEN` は自動提供）。
`AWS_ACCOUNT_ID` / `AWS_REGION` / `CLIENT_URL` はワークフロー内に直接定義されています。

---

## ステップ4: 初回デプロイ

GitHub Actions の deploy workflow を手動実行します。

```
Workflow: deploy.yml
Inputs:
  - deployment_mode: provisioning
  - environment: dev
```

**所要時間**: 約15分

**デプロイフロー:**
```
1. Terraform Apply (VPC/ECS/RDS/ALB/CloudFront作成)
   ↓
2. Docker Build + ECR Push
   ↓
3. ECS Task Definition作成
   ↓
4. ECS Service起動（Blue環境）
   ↓
5. CloudFront / DNS設定（hamilcar-hannibal.click）
```

**デプロイ確認:**
```bash
# ALB ターゲットヘルス確認
aws elbv2 describe-target-health --target-group-arn <ARN>

# ECS Task 状態確認
aws ecs describe-tasks \
  --cluster nestjs-hannibal-3-cluster \
  --tasks <TASK_ARN>
```

---

## ローカル開発環境セットアップ

### Backend (NestJS)

```bash
npm ci
cp .env.example .env
# DATABASE_URL=postgresql://user:pass@localhost:5432/hannibal
# NODE_ENV=development
# DEV_CLIENT_URL_LOCAL=http://localhost:5173
npm run start:dev  # http://localhost:3000/graphql
```

### Frontend (React + Vite)

```bash
cd client
npm ci
echo "VITE_GRAPHQL_ENDPOINT=http://localhost:3000/graphql" > .env
npm run dev  # http://localhost:5173
```

### Infrastructure (Terraform)

```bash
cd terraform/environments/dev

# terraform/environments/dev は HannibalDeveloperRole-Dev を AssumeRole してから実行
terraform plan
terraform apply
```

---

## 関連ドキュメント

- [CONTRIBUTING.md](../../CONTRIBUTING.md) — Issue駆動開発フロー（必読）
- [docs/setup/prerequisites.md](./prerequisites.md) — 手動作成リソース一覧
- [docs/operations/aws-resources.md](../operations/aws-resources.md) — 永続リソース・一時リソース一覧
- [docs/operations/iam-management.md](../operations/iam-management.md) — IAM権限設計
- [docs/architecture/](../architecture/) — システム設計詳細
- [docs/deployment/](../deployment/) — Blue/Green・Canaryデプロイ手順

---

## トラブルシューティング

### Terraform State Lock エラー

```bash
# 原因: 別の操作が実行中 or 異常終了
terraform force-unlock <LOCK_ID>
```

### ECS Task起動失敗

```bash
# CloudWatch Logs確認
aws logs tail /ecs/nestjs-hannibal-3 --follow
# 原因: ECS実行ロールの Secrets Manager 参照権限不足 / RDS managed secret 未作成
```

### Backend初期化エラー

```bash
# エラー: "Backend initialization required"
cd terraform/environments/dev
terraform init -reconfigure
```

---

**最終更新**: 2026-05-05
