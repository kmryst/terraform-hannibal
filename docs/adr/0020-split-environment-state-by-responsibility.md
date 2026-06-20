# 0020. 環境 state を責務単位で分割する

## ステータス

Accepted

## 日付

2026-06-20

## 決定内容

ADR 0014 で分離した `terraform/environments/dev/` の単一 state を、責務単位で 4 つの root module / state に分割する。同時に、子モジュールの責務を整理し、ディレクトリ階層をフラット化する。

### root module（state の単位）

| root module | state key | 内容 |
|---|---|---|
| `terraform/network/` | `network/terraform.tfstate` | VPC、subnet、Internet Gateway、NAT Gateway、route table |
| `terraform/database/` | `database/terraform.tfstate` | RDS PostgreSQL、DB subnet group、RDS Security Group |
| `terraform/service/` | `service/terraform.tfstate` | ECS、ALB、CodeDeploy、monitoring、ALB/ECS Security Group、ECS task execution IAM Role |
| `terraform/cdn/` | `cdn/terraform.tfstate` | CloudFront、S3 frontend、Route53 DNS record |

`terraform/foundation/` は ADR 0014 で分離済みであり、変更しない。

### 子モジュールの責務整理

| 変更 | 内容 |
|---|---|
| Security Group の移動 | `modules/security-groups` を廃止し、ALB SG は ALB モジュール、ECS SG は ECS モジュール、RDS SG は RDS モジュールがそれぞれ所有する |
| IAM Role の移動 | `modules/iam` を廃止し、ECS task execution role は ECS モジュールが所有する |
| Target Group の移動 | CodeDeploy モジュールから Target Group を ALB モジュールに移動する |
| ディレクトリのフラット化 | `modules/compute/ecs/` → `modules/ecs/`、`modules/storage/rds/` → `modules/rds/` のように、カテゴリ層を廃止してフラットにする |

### フラット化後のモジュール構成

```text
terraform/modules/
  cloudfront/
  codedeploy/
  dns/
  ecs/          ← Security Group と IAM Role を内包
  load-balancer/ ← Security Group と Target Group を内包
  monitoring/
  rds/          ← Security Group を内包
  s3/
  vpc/
```

### state 間の依存関係

state 間の参照は `terraform_remote_state` data source を使う。依存は上位層から下位層への一方向とし、循環参照は発生しない。

```text
foundation   (独立)
network/     (独立)
database/    → network/  (vpc_id, data_subnet_ids)
service/     → network/  (vpc_id, app_subnet_ids, public_subnet_ids)
             → database/ (rds_endpoint, master_user_secret_arn)
cdn/         → service/  (alb_dns_name, alb_zone_id)
```

## 背景

ADR 0014 で foundation と environments の state を分離した。しかし、`terraform/environments/dev/` には VPC、RDS、ECS、ALB、CodeDeploy、CloudFront、monitoring など全アプリケーションリソースが 1 つの state に入っている。

この構成には次の問題がある。

- `terraform plan` が全リソースを評価するため、ECS の task definition を変えたいだけでも VPC、RDS、CloudFront まで差分確認の対象になる
- 1 つの `terraform apply` の blast radius が全リソースに及ぶ。plan に予期しない差分が出た場合、影響範囲が環境全体になる
- 複数人が同時に作業する場合、state lock により同時に 1 人しか apply できない

子モジュールの責務にも問題がある。

- `security/security-groups` が ALB、ECS、RDS の Security Group を一括管理しており、1 つの SG を変えるだけで他の SG の state にも触れる
- `security/iam` が ECS task execution role を管理しており、ECS モジュールと責務が分かれている
- `cicd/codedeploy` が Target Group を所有しており、ALB の構成要素が deploy 戦略モジュールに入っている
- `modules/compute/ecs/` のようにカテゴリ層があるが、カテゴリ内に 1〜2 モジュールしかなく、階層の意味がない

## 検討した選択肢

### 現状維持（1 state）

- 長所: 追加の root module や `terraform_remote_state` 参照が不要
- 長所: apply 順序を考える必要がない
- 短所: plan/apply の blast radius が全リソースに及ぶ
- 短所: state lock で deploy が直列化する
- 短所: 変更しないリソースも毎回評価される

### モジュールごとに state を分割する（9 state）

- 長所: blast radius が最小になる
- 短所: ECS、ALB、CodeDeploy、Monitoring の間に循環依存がある（CodeDeploy は Monitoring の alarm 名を必要とし、Monitoring は ECS/ALB のリソース名を必要とする）
- 短所: 1 つの変更で複数 state を順序どおりに apply する必要が生じる
- 短所: `terraform_remote_state` の参照が爆発する
- 短所: 一緒に変わるリソースが別 state に分かれるため、deploy 時の apply 回数が増える

### 責務単位で 4 state に分割する

- 長所: 変更頻度と blast radius が異なるリソースを分離できる
- 長所: 一緒に変わるリソース（ECS、ALB、CodeDeploy、Monitoring）は同じ state に残るため、循環依存が発生しない
- 長所: state 間の依存が一方向の 4 層で収まり、apply 順序が明確
- 短所: `terraform_remote_state` 参照の設計と、既存 state からの移行が必要

### 2 state に分割する（network + それ以外）

- 長所: 分割が単純で移行コストが低い
- 短所: RDS と ECS/ALB が同じ state に残り、database 変更の blast radius が縮小しない
- 短所: CloudFront と ECS の変更頻度が異なるのに同じ apply 対象になる

## 採択理由

分割の原則は「一方を変えても他方に影響しないものを別 state にする」である。

- VPC の CIDR やsubnet を変えても、CloudFront には影響しない → network と cdn は別 state
- RDS のインスタンスサイズを変えても、VPC には影響しない → database と network は別 state
- ECS の task definition を変えても、VPC と RDS の state には触れない → service と network/database は別 state
- CloudFront の cache 設定を変えても、ECS には影響しない → cdn と service は別 state

逆に、一緒に変わるものは同じ state に置く。ECS の task definition を変えたら ALB の health check、CodeDeploy の設定、Monitoring の alarm も確認が要る。これらを別 state にすると 1 つの変更で複数回 apply が必要になり、循環依存も発生する。service state に閉じることで、これらの問題を避ける。

モジュールごとに 9 state にする案は、上記の循環依存と apply 回数の問題から採用しない。2 state 分割は blast radius の縮小が不十分である。4 state は分離の利点と管理コストのバランスが取れている。

子モジュールの責務整理は、state 分割と同時に行う。Security Group、IAM Role、Target Group を使用するモジュールに移動することで、root module 間のモジュール参照の受け渡しが減り、各モジュールが `vpc_id` を受け取れば内部で完結する構成になる。

ディレクトリのフラット化は、カテゴリ層にモジュールが 1〜2 個しかなく、階層の意味がないため行う。

## 影響

### state key

| root module | state key |
|---|---|
| `terraform/foundation/` | `foundation/terraform.tfstate`（変更なし） |
| `terraform/network/` | `network/terraform.tfstate` |
| `terraform/database/` | `database/terraform.tfstate` |
| `terraform/service/` | `service/terraform.tfstate` |
| `terraform/cdn/` | `cdn/terraform.tfstate` |

### apply 順序

新規構築時は `network → database → service → cdn` の順で apply する。destroy は逆順とする。foundation は独立しており、順序に含めない。

通常の変更では、変更対象の root module だけを apply すれば済む。下位層を変更した場合は、上位層で `terraform plan` を実行して影響を確認する。

### 既存 dev 環境からの移行

既存の `terraform/environments/dev/` から新しい 4 root module への移行は、`terraform state mv` を使って既存 state からリソースを移動する。移行手順の詳細は実装 Issue で定義する。

移行中は既存 state と新 state の両方が存在する期間があるため、同時 apply を避ける運用が必要になる。

### 廃止対象

| 対象 | 理由 |
|---|---|
| `terraform/environments/dev/` | 4 root module に分割されるため廃止 |
| `terraform/modules/security/security-groups/` | SG が各モジュールに移動するため廃止 |
| `terraform/modules/security/iam/` | ECS task execution role が ECS モジュールに移動するため廃止 |
| `modules/` のカテゴリ層ディレクトリ | フラット化により不要 |

### CI / workflow への影響

- `pr-check.yml` の `terraform validate` 対象パスが `terraform/environments/dev` から 4 root module に変わる
- `deploy.yml` / `destroy.yml` の `working-directory` と apply 対象が変わる
- Terraform plan の Change Detection パスフィルタも更新が必要
- IAM Role の Resource scope が root module ごとに異なる可能性があり、Issue #392 再設計時に検討する

## リスクと再検討条件

- `terraform state mv` の移行ミスによるリソースの意図しない再作成
- `terraform_remote_state` 参照の設定ミスによる plan 失敗
- 4 root module の apply 順序の誤りによる依存解決の失敗
- root module 数の増加による CI 実行時間の増加

サービスが複数に分かれ、チームごとに独立した deploy が必要になった場合は、`service/` をさらにサービス単位に分割する。現時点では単一サービスのため、service state は 1 つとする。

## 関連

- [Issue #394](https://github.com/kmryst/terraform-hannibal/issues/394)
- [ADR 0014: Terraform foundation / environments のルートモジュールと state を分離する](./0014-separate-terraform-foundation-and-environment-state.md)
- [ADR 0019: Terraform state を PR 単位で分離する Preview Environment を採用する](./0019-adopt-pr-preview-environment-with-isolated-state.md)（Superseded）
- [Terraform 環境分離設計](../terraform-environments.md)
