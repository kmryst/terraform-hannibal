# Terraform 環境分離設計

## 概要

このプロジェクトは Terraform state を責務単位で分割し、plan/apply の影響範囲を限定する設計です。

`terraform/foundation/` は IAM / OIDC / Permission Boundary などの永続基盤を管理します（ADR 0014）。アプリケーションリソースは責務ごとに 4 つの root module に分割します（ADR 0020）。

Preview Environment は state 分割後の構成を前提に再検討します（ADR 0019 Superseded）。

## State 管理方針

- **バックエンド**: S3 バケット `nestjs-hannibal-3-terraform-state`
- **State lock**: S3 lockfile を正とする。DynamoDB lock table は #189 まで移行期間用として併用する
- **バケットは共有可**（同一バケット内で key 分離すれば競合しない）

| root module | State キー | 内容 |
|---|---|---|
| `terraform/foundation/` | `foundation/terraform.tfstate` | IAM、OIDC、Permission Boundary、CloudTrail、Athena、Budgets |
| `terraform/network/` | `network/terraform.tfstate` | VPC、subnet、Internet Gateway、NAT Gateway、route table、ALB/ECS/RDS Security Group |
| `terraform/database/` | `database/terraform.tfstate` | RDS PostgreSQL、DB subnet group |
| `terraform/service/` | `service/terraform.tfstate` | ECS、ALB、CodeDeploy、monitoring、ECS IAM Role |
| `terraform/cdn/` | `cdn/terraform.tfstate` | CloudFront、S3 frontend、Route53 DNS record |

### 分割の原則

一方を変えても他方に影響しないものを別 state にする。逆に、一緒に変わるリソースは同じ state に置く。

- VPC の CIDR を変えても CloudFront には影響しない → network と cdn は別 state
- RDS のインスタンスサイズを変えても VPC には影響しない → database と network は別 state
- ECS の task definition を変えても VPC と RDS の state には触れない → service は独立して apply できる
- CloudFront の cache 設定を変えても ECS には影響しない → cdn と service は別 state
- ECS を変えたら ALB の health check、CodeDeploy、Monitoring も確認が要る → service state にまとめる

### state 間の依存関係

依存は上位層から下位層への一方向とし、`terraform_remote_state` data source で参照する。循環参照は発生しない。

```text
foundation   (独立)
network/     (独立)
database/    → network/  (vpc_id, data_subnet_ids, rds_security_group_id)
service/     → network/  (vpc_id, app_subnet_ids, public_subnet_ids, alb_security_group_id, ecs_security_group_id)
             → database/ (rds_endpoint, master_user_secret_arn)
cdn/         → service/  (alb_dns_name, alb_zone_id)
```

### apply 順序

新規構築時は `network → database → service → cdn` の順で apply する。destroy は逆順とする。通常の変更では、変更対象の root module だけを apply すれば済む。

### 既存 dev 環境からの移行

既存の `terraform/environments/dev/` から 4 root module への移行は、`terraform state mv` を使う。移行手順の詳細は [State 分割移行ガイド](./operations/state-migration-guide.md) を参照する。

Terraform の `init` / `plan` / `apply` / force-unlock / import / drift 確認は [Terraform Runbook](./operations/terraform-runbook.md) を参照します。
state 復元や誤変更の rollback は [Terraform Rollback Plan](./operations/rollback-plan.md) を参照します。

## 子モジュールの構成

state 分割に伴い、子モジュールの責務を整理し、ディレクトリ階層をフラット化する。

### 責務整理

| 変更 | 内容 |
|---|---|
| Security Group の統合 | `modules/security-groups` を廃止し、ALB/ECS/RDS の Security Group を VPC モジュールに統合する。SG 間の相互参照で state 間の循環依存が発生するため network state にまとめる |
| IAM Role の移動 | `modules/iam` を廃止し、ECS task execution role は ECS モジュールが所有する |
| Target Group の移動 | CodeDeploy モジュールから Target Group を ALB モジュールに移動する |

### フラット化後の構成

```text
terraform/modules/
  cloudfront/
  codedeploy/
  dns/
  ecs/          ← IAM Role を内包
  load-balancer/ ← Target Group を内包
  monitoring/
  rds/
  s3/
  vpc/          ← ALB/ECS/RDS Security Group を内包
```

## リソース命名方針

- 共有環境は `var.project_name`（`nestjs-hannibal-3`）と `var.environment` を組み合わせてリソース名に使う
- 例: `${var.project_name}-${var.environment}-cluster`
- 多くのモジュールはすでに `environment` 変数を受け取っているため、prod 追加時も同じ命名規則が適用される

## PR Preview Environment

PR 単体の変更を一時 AWS 環境で確認する Preview Environment は、state 分割後の構成を前提に再検討します。以前の検討内容は [ADR 0019](./adr/0019-adopt-pr-preview-environment-with-isolated-state.md)（Superseded）を参照してください。

## 後続フェーズ

1. state 分割の実装（`terraform state mv` による既存リソースの移行）を行う
2. 子モジュールの責務整理とディレクトリフラット化を実施する
3. CI / workflow（`pr-check.yml`、`deploy.yml`、`destroy.yml`）を新しい root module 構成に対応させる
4. staging / production を独立した共有環境として整備し、直列 deploy と承認を設計する
5. state 分割後の構成を前提に、Preview Environment を再検討する

## 新環境（staging / prod）を追加するときのチェックリスト

state 分割後は、環境ごとに 4 root module（network / database / service / cdn）を用意します。以下は暫定チェックリストであり、state 分割の実装完了後に更新します。

### 1. Terraform

- [ ] `terraform/network/`、`terraform/database/`、`terraform/service/`、`terraform/cdn/` の各 root module に prod 用の `backend.tf`（state key）と `terraform.tfvars` を用意する
- [ ] 各 root module で `terraform init && terraform plan` を実行し、差分を確認してから `network → database → service → cdn` の順で `terraform apply`

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

- [ ] `deploy.yml` / `destroy.yml` の各 root module（network / database / service / cdn）に prod 用の変数を追加する
- [ ] CodeDeploy アプリケーション・デプロイグループを prod 用に別途作成（Terraform が管理）

## 停止コスト運用（dev 固有）

dev 環境は月額最適化のため「使わないときは destroy」という運用をしています。prod に同じ運用を適用すると **RDS の再作成コストや DNS 切り替えリスク**があるため、prod は常時稼働を推奨します。
