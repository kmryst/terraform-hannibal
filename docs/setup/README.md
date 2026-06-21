# セットアップガイド

## セットアップ概要

このプロジェクトは **Terraform + GitHub Actions** で完全自動化されています。
手動セットアップは **Terraform State初期化 → IAM/OIDC設定** の2ステップのみ。

GitHub Actions から AWS への認証は **OIDC（OpenID Connect）** を使います。
長期 Access Key は不要です。

---

## ステップ1: Terraform State初期化（初回のみ）

### 1-1. S3 state bucket 作成

Terraform state 用のバックエンドリソースを手動で作成します。
State lock は S3 lockfile（`use_lockfile = true`）を使用します。

```bash
aws s3 mb s3://nestjs-hannibal-3-terraform-state --region ap-northeast-1
aws s3api put-bucket-versioning \
  --bucket nestjs-hannibal-3-terraform-state \
  --versioning-configuration Status=Enabled
```

### 1-2. Backend設定確認

```
terraform/
├── foundation/   # 基盤（IAM/OIDC/Athena等）
├── network/      # VPC・subnet・Security Group
├── database/     # RDS PostgreSQL
├── service/      # ECS・ALB・CodeDeploy・monitoring
└── cdn/          # CloudFront・S3・DNS
```

各 root module の `backend.tf` 例（`terraform/service/backend.tf`）:
```hcl
terraform {
  backend "s3" {
    bucket       = "nestjs-hannibal-3-terraform-state"
    key          = "service/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

`use_lockfile = true` により、Terraform は state key に対応する `.tflock` オブジェクトを S3 上で作成・削除してロックします。

### 1-3. tfvars ファイル作成

`terraform/foundation` は変数を `terraform.tfvars` で管理します（gitignore 済み）。
`terraform.tfvars.example` を参考に実値を設定してください。

```bash
cp terraform/foundation/terraform.tfvars.example terraform/foundation/terraform.tfvars
# エディタで alert_email を通知先メールアドレスに書き換える
```

`terraform.tfvars.example` の内容:

```hcl
alert_email = "your-email@example.com"
```

### 1-4. 初期化実行

```bash
cd terraform/foundation
terraform init

for dir in network database service cdn; do
  cd ../terraform/$dir
  terraform init
done
```

`terraform init -reconfigure` で backend 設定を再読込できます。
`terraform/cdn` は `client/dist` を参照するため、ローカルで plan する場合は事前に frontend build を実行します。

S3 lockfile の実動作確認、force-unlock、drift 確認は [Terraform Runbook](../operations/terraform-runbook.md) を参照します。
dev 環境が destroy 済みの場合、`Plan: ... to add` と exit code `2` は正常系です。

---

## ステップ2: IAM/OIDC設定（初回のみ）

### 2-1. IAM User作成

開発者手動操作用のユーザーを作成します（GitHub Actions用は不要）。

```bash
aws iam create-user --user-name hannibal
```

### 2-2. foundation Terraform apply

事前に `terraform/foundation/terraform.tfvars` を作成済みであることを確認します（ステップ1-3参照）。

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
- `aws_cloudtrail` trail `nestjs-hannibal-3` — management events の監査ログ記録
- Athena Workgroup / Database / Budget アラーム 等

foundation apply 後、GitHub Actions の deploy/destroy は OIDC で `HannibalCICDRole-Dev` を
AssumeRoleWithWebIdentity します。Access Key の発行・登録は不要です。
初回構築後に `terraform/foundation` を更新する場合は `HannibalFoundationRole-Dev` を assume し、
`HannibalDeveloperRole-Dev` では foundation apply を実行しません。

---

## ステップ3: GitHub Secrets / Variables

AWS 認証は OIDC のため、**長期 Access Key の登録は不要**です。

現在 GitHub Actions が参照する Secret はありません（`GITHUB_TOKEN` は自動提供）。
ロール ARN、リージョン、Terraform 変数として渡す ARN / Hosted Zone ID は GitHub Variables で管理します。

主な Variables:

- `AWS_CICD_ROLE_ARN`
- `AWS_PR_PLAN_ROLE_ARN`
- `AWS_REGION`
- `ECR_REPOSITORY_URL`
- `ALB_CERTIFICATE_ARN`
- `ACM_CERTIFICATE_ARN_US_EAST_1`
- `HOSTED_ZONE_ID`

---

## ステップ4: 初回デプロイ

GitHub Actions の deploy workflow を手動実行します。

```
Workflow: deploy.yml
Inputs:
  - deployment_mode: provisioning
```

**所要時間**: 約15分

`deploy.yml` は PR gate 通過済みの `main` から手動実行する前提です。backend/frontend の build・test は `pr-check.yml` に委譲し、deploy workflow では再実行しません。

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
# HannibalDeveloperRole-Dev を AssumeRole してから実行
# 通常の deploy/destroy は deploy.yml / destroy.yml を使用する
terraform -chdir=terraform/service plan
```

---

## 関連ドキュメント

- [CONTRIBUTING.md](../../CONTRIBUTING.md) — Issue駆動開発フロー（必読）
- [docs/setup/prerequisites.md](./prerequisites.md) — 手動作成リソース一覧
- [docs/operations/aws-resources.md](../operations/aws-resources.md) — 永続リソース・一時リソース一覧
- [docs/operations/terraform-runbook.md](../operations/terraform-runbook.md) — Terraform init / plan / apply / state lock / import / drift 確認
- [docs/operations/rollback-plan.md](../operations/rollback-plan.md) — Terraform rollback / state 復元手順
- [docs/operations/iam-management.md](../operations/iam-management.md) — IAM権限設計
- [docs/architecture/](../architecture/) — システム設計詳細
- [docs/deployment/](../deployment/) — Blue/Green・Canaryデプロイ手順

---

## トラブルシューティング

### Terraform State Lock エラー

原因は別の操作が実行中、または前回実行の異常終了です。
force-unlock 手順は [Terraform Runbook](../operations/terraform-runbook.md#force-unlock) を参照してください。
state 復元が必要な場合は [Terraform Rollback Plan](../operations/rollback-plan.md) を参照してください。

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
