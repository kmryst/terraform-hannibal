# Terraform 環境分離設計

## 概要

このプロジェクトは `terraform/environments/<env>/` 配下に環境ごとのルートモジュールを置き、State を分離する設計です。現在、AWS リソースを管理する環境は `dev` のみです。

`preview` は PR ごとの一時 AWS 環境を作るための環境タイプとして検討していましたが、Terraform state をサービス単位で分割する設計を先に行う方針に変更しました。Preview 構成は state 分割後に再検討します。

## State 管理方針

- **バックエンド**: S3 バケット `nestjs-hannibal-3-terraform-state`
- **State lock**: S3 lockfile を正とする。DynamoDB lock table は #189 まで移行期間用として併用する
- **State キーの命名規則**: 共有環境は `environments/<env>/terraform.tfstate`（環境ごとに key を分ける）
- **バケットは共有可**（同一バケット内で key 分離すれば競合しない）

| 環境 | State キー |
|------|-----------|
| dev  | `environments/dev/terraform.tfstate` |
| staging（未作成） | `environments/staging/terraform.tfstate` |
| prod（未作成） | `environments/prod/terraform.tfstate` |

Terraform の `init` / `plan` / `apply` / force-unlock / import / drift 確認は [Terraform Runbook](./operations/terraform-runbook.md) を参照します。
state 復元や誤変更の rollback は [Terraform Rollback Plan](./operations/rollback-plan.md) を参照します。

## リソース命名方針

- 共有環境は `var.project_name`（`nestjs-hannibal-3`）と `var.environment` を組み合わせてリソース名に使う
- 例: `${var.project_name}-${var.environment}-cluster`
- 多くのモジュールはすでに `environment` 変数を受け取っているため、prod 追加時も同じ命名規則が適用される

## PR Preview Environment

PR 単体の変更を一時 AWS 環境で確認する Preview Environment は、Terraform state のサービス単位分割を先に設計し、その上で構成を再検討します。以前の検討内容は [ADR 0019](./adr/0019-adopt-pr-preview-environment-with-isolated-state.md)（Superseded）を参照してください。

## 後続フェーズ

1. Terraform state をサービス単位で分割する設計を行う
2. staging / production を独立した共有環境として整備し、直列 deploy と承認を設計する
3. state 分割後の構成を前提に、Preview Environment を再検討する

## 新環境（staging / prod）を追加するときのチェックリスト

以下の手順で新環境を追加できます。

### 1. Terraform

- [ ] `terraform/environments/dev/` を `terraform/environments/prod/` にコピー
- [ ] `backend.tf` の `key` を `environments/prod/terraform.tfstate` に変更
- [ ] 各変数のデフォルト値・`terraform.tfvars` を prod 向けに更新（下表参照）
- [ ] `terraform init && terraform plan` で差分を確認してから `terraform apply`

### 2. 環境ごとに変わる主な設定値

| 変数 | dev 例 | prod 時の検討 |
|------|--------|--------------|
| `environment` | `"dev"` | `"prod"` |
| `project_name` | `"nestjs-hannibal-3"` | 必要なら環境別サフィックスを付ける |
| `domain_name` | `"hamilcar-hannibal.click"` | 本番ドメインに変更 |
| `hosted_zone_id` | 既存 Zone ID | prod 用 Route53 Zone を用意（または同一 Zone でサブドメイン分離） |
| `acm_certificate_arn_us_east_1` | dev 用 CloudFront ACM ARN | prod 用 CloudFront 証明書（us-east-1 必須） |
| `alb_certificate_arn` | dev 用 ALB ACM ARN | prod 用 ALB 証明書（ALB と同じリージョン） |
| `cloudfront_oac_id` | dev 用 OAC ID | prod 用 OAC を手動作成して指定 |
| `client_url_for_cors` | `"https://hamilcar-hannibal.click"` | prod ドメインに変更 |
| `db_instance_class` | `db.t3.micro` | prod は `db.t3.small` 以上推奨 |
| `desired_task_count` | `1` | prod は `2` 以上推奨（Multi-AZ と合わせて） |
| `enable_cloudfront` | `true` | `true` |

### 3. AWS / IAM

- [ ] ECR リポジトリ: prod でも同一リポジトリを使うか、環境別に作るかを決める（現状は手動作成のため、使い回す場合は変数で指定するだけでよい）
- [ ] IAM ロール (`HannibalCICDRole-Dev` 相当) を prod 用に作成
- [ ] GitHub Actions の `role-to-assume` を prod ロールの ARN に変更

### 4. CI/CD

- [ ] `deploy.yml` の `working-directory: ./terraform/environments/dev` を `prod` に変更（または environment 入力で切り替え）
- [ ] CodeDeploy アプリケーション・デプロイグループを prod 用に別途作成（Terraform が管理）

## 停止コスト運用（dev 固有）

dev 環境は月額最適化のため「使わないときは destroy」という運用をしています。prod に同じ運用を適用すると **RDS の再作成コストや DNS 切り替えリスク**があるため、prod は常時稼働を推奨します。
