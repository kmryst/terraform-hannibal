# State 分割移行ガイド

旧 `terraform/environments/dev/` 単一ルートモジュールから、4つのルートモジュール (`network`, `database`, `service`, `cdn`) への state 分割移行手順。

## 前提条件

- dev 環境が destroy 済みであること（ADR 0008 オンデマンド運用方針に基づく）
- AWS CLI がセットアップ済みで、適切な権限があること
- Terraform がインストール済みであること

> **注意**: この移行ガイドはリファレンス用です。実際の実行にはヒューマンオーバーサイトが必要です。

## 概要

旧 state (`environments/dev/terraform.tfstate`) のリソースを、以下の 4 つの新 state に分割します:

| 新ルートモジュール | state key | 含まれるリソース |
|---|---|---|
| `terraform/network/` | `network/terraform.tfstate` | VPC, Security Groups |
| `terraform/database/` | `database/terraform.tfstate` | RDS |
| `terraform/service/` | `service/terraform.tfstate` | ALB, ECS, IAM, CodeDeploy, Monitoring |
| `terraform/cdn/` | `cdn/terraform.tfstate` | CloudFront, S3, DNS |

## Step 1: 各ルートモジュールの初期化

```bash
cd terraform/network && terraform init
cd terraform/database && terraform init
cd terraform/service && terraform init
cd terraform/cdn && terraform init
```

## Step 2: network state への移行

旧 state では VPC は `module.vpc`、Security Groups は `module.security_groups` として管理されていた。
新構成では SG が vpc モジュールに統合されたため、個別リソースのリマッピングが必要。

```bash
# VPC 関連リソース（module.vpc → module.vpc でアドレス同一）
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=network/terraform.tfstate \
  module.vpc module.vpc

# Security Groups → vpc モジュールへ統合（個別リソースのリマッピング）
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=network/terraform.tfstate \
  module.security_groups.aws_security_group.alb \
  module.vpc.aws_security_group.alb

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=network/terraform.tfstate \
  module.security_groups.aws_security_group.ecs \
  module.vpc.aws_security_group.ecs

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=network/terraform.tfstate \
  module.security_groups.aws_security_group.rds \
  module.vpc.aws_security_group.rds

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=network/terraform.tfstate \
  module.security_groups.aws_security_group_rule.alb_egress \
  module.vpc.aws_security_group_rule.alb_egress

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=network/terraform.tfstate \
  module.security_groups.aws_security_group_rule.alb_ingress_https \
  module.vpc.aws_security_group_rule.alb_ingress_https

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=network/terraform.tfstate \
  module.security_groups.aws_security_group_rule.ecs_egress \
  module.vpc.aws_security_group_rule.ecs_egress

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=network/terraform.tfstate \
  module.security_groups.aws_security_group_rule.ecs_ingress_from_alb \
  module.vpc.aws_security_group_rule.ecs_ingress_from_alb

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=network/terraform.tfstate \
  module.security_groups.aws_security_group_rule.rds_ingress_from_ecs \
  module.vpc.aws_security_group_rule.rds_ingress_from_ecs
```

## Step 3: database state への移行

```bash
# RDS（アドレス同一）
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=database/terraform.tfstate \
  module.rds module.rds
```

## Step 4: service state への移行

### IAM → ecs モジュールへ統合

```bash
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.iam.data.aws_caller_identity.current \
  module.ecs.data.aws_caller_identity.current

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.iam.aws_iam_role.ecs_task_execution_role \
  module.ecs.aws_iam_role.ecs_task_execution_role

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.iam.aws_iam_role.ecs_task_role \
  module.ecs.aws_iam_role.ecs_task_role

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.iam.aws_iam_role_policy_attachment.ecs_task_execution_role_policy \
  module.ecs.aws_iam_role_policy_attachment.ecs_task_execution_role_policy

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.iam.aws_iam_policy.secrets_manager_access \
  module.ecs.aws_iam_policy.secrets_manager_access

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.iam.aws_iam_role_policy_attachment.secrets_manager_access \
  module.ecs.aws_iam_role_policy_attachment.secrets_manager_access
```

### Load Balancer（アドレス同一）

```bash
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.load_balancer module.load_balancer
```

### Target Groups: codedeploy → load_balancer へ移動

```bash
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.codedeploy.aws_lb_target_group.blue \
  module.load_balancer.aws_lb_target_group.blue

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.codedeploy.aws_lb_target_group.green \
  module.load_balancer.aws_lb_target_group.green
```

### ECS（アドレス同一）

```bash
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.ecs module.ecs
```

### CodeDeploy（アドレス同一、target group 除く）

```bash
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.codedeploy.aws_codedeploy_app.this \
  module.codedeploy.aws_codedeploy_app.this

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.codedeploy.aws_codedeploy_deployment_group.this \
  module.codedeploy.aws_codedeploy_deployment_group.this

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.codedeploy.aws_iam_role.codedeploy \
  module.codedeploy.aws_iam_role.codedeploy

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.codedeploy.aws_iam_role_policy_attachment.codedeploy \
  module.codedeploy.aws_iam_role_policy_attachment.codedeploy

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.codedeploy.aws_s3_bucket.codedeploy \
  module.codedeploy.aws_s3_bucket.codedeploy

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.codedeploy.aws_s3_bucket_versioning.codedeploy \
  module.codedeploy.aws_s3_bucket_versioning.codedeploy

terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.codedeploy.aws_s3_bucket_server_side_encryption_configuration.codedeploy \
  module.codedeploy.aws_s3_bucket_server_side_encryption_configuration.codedeploy
```

### Monitoring（アドレス同一）

```bash
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  module.monitoring module.monitoring
```

### ALB Origin Verify Header（ルートレベルリソース）

```bash
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=service/terraform.tfstate \
  random_password.alb_origin_verify_header \
  random_password.alb_origin_verify_header
```

## Step 5: cdn state への移行

```bash
# S3
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=cdn/terraform.tfstate \
  module.s3 module.s3

# CloudFront
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=cdn/terraform.tfstate \
  module.cloudfront module.cloudfront

# DNS
terraform state mv \
  -state=environments/dev/terraform.tfstate \
  -state-out=cdn/terraform.tfstate \
  module.dns module.dns
```

## Step 6: 移行後の検証

各ルートモジュールで `terraform plan` を実行し、リソースの再作成が発生しないことを確認します。

```bash
cd terraform/network && terraform plan
cd terraform/database && terraform plan
cd terraform/service && terraform plan
cd terraform/cdn && terraform plan
```

**期待される結果**: すべてのモジュールで "No changes" または差分が最小限（タグ変更等のみ）であること。

## 注意事項

- この移行は dev 環境が destroy 済みの状態を前提としています（ADR 0008 オンデマンド運用方針）
- 環境がライブの場合、state mv の実行順序に注意が必要です（依存関係の方向: network → database → service → cdn）
- `terraform plan` で リソース再作成が検出された場合は、state アドレスのマッピングを確認してください
- この移行スクリプトはリファレンス用です。実際の実行にはヒューマンオーバーサイトが必要です
