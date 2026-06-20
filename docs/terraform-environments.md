# Terraform 環境分離設計

## 概要

このプロジェクトは `terraform/environments/<env>/` 配下に環境ごとのルートモジュールを置き、State を分離する設計です。現在は `dev` のみ実稼働しています。

`preview` は PR ごとの一時 AWS 環境を作るための環境タイプとして追加する方針です。`preview` は Git branch ではなく PR 番号に紐づく短命環境であり、実装は後続 Issue で扱います。

## State 管理方針

- **バックエンド**: S3 バケット `nestjs-hannibal-3-terraform-state`
- **State lock**: S3 lockfile を正とする。DynamoDB lock table は #189 まで移行期間用として併用する
- **State キーの命名規則**: 共有環境は `environments/<env>/terraform.tfstate`（環境ごとに key を分ける）。PR preview は短命環境を PR 番号ごとに複数作るため、`preview/pr-<number>/terraform.tfstate` を使う
- **バケットは共有可**（同一バケット内で key 分離すれば競合しない）

| 環境 | State キー |
|------|-----------|
| dev  | `environments/dev/terraform.tfstate` |
| preview（未作成） | `preview/pr-<number>/terraform.tfstate` |
| staging（未作成） | `environments/staging/terraform.tfstate` |
| prod（未作成） | `environments/prod/terraform.tfstate` |

Terraform の `init` / `plan` / `apply` / force-unlock / import / drift 確認は [Terraform Runbook](./operations/terraform-runbook.md) を参照します。
state 復元や誤変更の rollback は [Terraform Rollback Plan](./operations/rollback-plan.md) を参照します。

## リソース命名方針

- 共有環境は `var.project_name`（`nestjs-hannibal-3`）と `var.environment` を組み合わせてリソース名に使う
- 例: `${var.project_name}-${var.environment}-cluster`
- 多くのモジュールはすでに `environment` 変数を受け取っているため、prod 追加時も同じ命名規則が適用される
- PR preview は PR 番号単位で一時環境を並列作成するため、AWS environment name は `preview-pr-<number>`、resource prefix は `hannibal-pr-<number>` とする
- 例: PR #101 の preview は environment name `preview-pr-101`、resource prefix `hannibal-pr-101`

## PR Preview Environment（設計）

Preview Environment は、PR 単体の Terraform / アプリ変更を一時 AWS 環境で確認するための環境タイプです。PR #101 のような Git branch を作るのではなく、PR 番号を入力として AWS 環境名、state key、resource prefix を作ります。

| 項目 | PR #101 の例 |
|---|---|
| Terraform root module | `terraform/environments/preview/` |
| Terraform backend key | `preview/pr-101/terraform.tfstate` |
| AWS environment name | `preview-pr-101` |
| AWS resource prefix | `hannibal-pr-101` |

PR ごとの root module ディレクトリは作りません。`terraform/environments/preview/` を共通の入口とし、backend key と入力変数で PR ごとの state / リソース名を分けます。

初期実装では、PR 作成時に preview 環境を自動作成しません。必要な PR だけ GitHub Actions の `workflow_dispatch` で PR 番号を入力し、手動で create / destroy します。destroy は create と同じ backend key を指定し、確認入力を必須にします。

staging / production は PR ごとに複製しません。これらは共有環境として扱い、deploy は concurrency control や承認で直列化します。Preview Environment は production の代替ではなく、PR 単体確認用の短命環境です。

リスクと注意点:

- PR close / merge 後の destroy 漏れにより、AWS リソースと state が残り続ける
- 同時稼働数に比例してコストが増える
- VPC、ALB、Target Group、EIP、RDS、IAM Role などの AWS quota に近づく可能性がある
- preview create / destroy には write 権限が必要であり、PR plan 用 read-only Role とは別に IAM Role / Permission Boundary を設計する必要がある
- create と destroy の backend key がずれると、意図した preview 環境を消せない、または別環境を操作するリスクがある
- `hannibal-pr-<number>` を prefix にしても、AWS リソースごとの長さ制限やグローバル一意制約を確認する必要がある
- 共有環境の `nestjs-hannibal-3-*` と preview の `hannibal-pr-*` が同一アカウントに混在するため、タグと命名で環境タイプを識別できるようにする

設計判断の詳細は [ADR 0019](./adr/0019-adopt-pr-preview-environment-with-isolated-state.md) を参照します。

## 後続フェーズ

Preview Environment は段階的に実装します。

1. `terraform/environments/preview/` を追加し、`environment = "preview"` と `pr_number` から preview 用の environment name / resource prefix を作れるようにする
2. `workflow_dispatch` で PR 番号を受け取り、`preview/pr-<number>/terraform.tfstate` を backend key として使う preview create workflow を追加する
3. 同じ backend key と確認入力を使う preview destroy workflow を追加する
4. preview 用 IAM Role / Permission Boundary を設計し、dev deploy / destroy Role や PR plan Role と責務を分ける
5. destroy 漏れ検知、PR close / merge 後の自動 destroy、同時稼働数上限を検討する
6. staging / production を独立した共有環境として整備し、直列 deploy と承認を設計する

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
