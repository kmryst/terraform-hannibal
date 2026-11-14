# terraform-hannibal AWS 構成 inventory

- 作成日: 2026-11-14
- 入力: 調査担当 3 人の報告（インフラ / CI/CD / データ運用。原文はリポジトリ外の作業メモで、コミットしていない）と、突き合わせ担当によるリポジトリのコード確認。実環境（AWS CLI・gh・terraform）は問い合わせていない
- 対象環境: **dev 環境（Region は ap-northeast-1）だけ**。根拠:
  - git 管理下の IaC は `terraform/` の 6 root module（foundation / network / database / service / cdn / observability）だけ。旧 `terraform/environments/dev/` は存在しない（`docs/terraform-environments.md:75-77`）
  - `deploy.yml` は各 root module に `-var="environment=dev"` を固定で渡す（`.github/workflows/deploy.yml:156,166,184,207`）。prod を渡す workflow・tfvars は無い
  - 全 root module の provider は `region = "ap-northeast-1"` 固定で、別 Region の provider alias は無い（`terraform/*/provider.tf`）
  - そのため `environment == "prod"` の分岐（NAT gateway の AZ ごと配置、RDS の Multi-AZ・保持 30 日・backup / maintenance window・deletion protection）は描かない
- tfvars: `terraform/foundation/terraform.tfvars` のキー名は `alert_email` だけ（tfvars 由来。値は書かない）。ほかの root module に tfvars は無い
- 名前の扱い: AWS 上の実名（bucket 名・role 名・log group 名・ドメイン名・custom header 名など）は書かず、Terraform のリソースアドレスで示す

## 「作図」列の凡例

| 値 | 意味 |
| --- | --- |
| 描く | 図に要素・線として描く |
| ラベル | 独立した要素にせず、別の要素のラベルに書く |
| 描かない（理由） | 図に描かない。README 本文に回すものは理由に書く |
| 要判断 | ユーザーの判断が要る（末尾「ユーザー判断が要る点」） |

「管理方法」列: IaC = Terraform で作成・管理。管理外 = 手動作成（`docs/operations/manual-resources.md`）で、Terraform は data source・変数で参照するだけ。

---

## リソース一覧

パスはリポジトリ root からの相対パス。

### 利用者・外部

| サービス名 | リソース名 | 役割 | 管理方法 | 作図 | 観点 | 根拠 |
| --- | --- | --- | --- | --- | --- | --- |
| ブラウザ（利用者） | — | React SPA（Apollo Client + Mapbox GL JS）を実行する | — | 描く | request-flow | `client/src/main.tsx:33-42`、`client/src/components/MapContainer.tsx:81-126` |
| Mapbox（AWS 外） | Mapbox の style・tileset API | 衛星画像の style（`satellite-v9`）と地形（`terrain-rgb`）を返す | 管理外（外部サービス） | 描く | request-flow | `client/src/services/mapSetup.ts:38-43,67-75` |
| GitHub Actions（AWS 外） | `deploy.yml` / `destroy.yml` | AWS を変更する workflow はこの 2 本だけ（どちらも `workflow_dispatch`） | — | 描く | operations | `.github/workflows/deploy.yml:8-19`、`.github/workflows/destroy.yml:7-30` |
| GitHub Actions（AWS を使わない workflow） | `pr-check.yml`、`codeql.yml`、`dependency-audit.yml` ほか | lint・test・SAST など。AWS 認証なし | — | 描かない（AWS の構成に関与しない） | — | `.github/workflows/pr-check.yml:1-398`（`role-to-assume` は deploy / destroy だけ: `deploy.yml:34`、`destroy.yml:27`） |
| 開発者端末（人の手動操作） | `scripts/game-day/run-ecs-task-stop-experiment.sh` | Game Day で FIS の実験を開始する | — | 描く | operations | `scripts/game-day/run-ecs-task-stop-experiment.sh:96`、`docs/operations/runbook.md:309-323` |

### グローバル（Region に属さない）

| サービス名 | リソース名 | 役割 | 管理方法 | 作図 | 観点 | 根拠 |
| --- | --- | --- | --- | --- | --- | --- |
| Amazon Route 53 | hosted zone | 公開ドメインの名前解決 | 管理外（data source で参照） | 描く | request-flow | `terraform/modules/dns/main.tf:3`、`docs/operations/manual-resources.md` |
| Amazon Route 53 | `aws_route53_record.www`（apex → CloudFront の alias record）、`aws_route53_record.api`（`api.` サブドメイン → ALB の alias record） | 利用者向けは CloudFront、CloudFront の API origin 向けは ALB を指す | IaC | ラベル（Route 53 の要素に含める） | request-flow | `terraform/modules/dns/route53.tf:2-30`、`terraform/cdn/main.tf:27,42-44` |
| Amazon CloudFront | `aws_cloudfront_distribution.main` | origin は 2 つ: S3（default behavior）と ALB（`/graphql`・`/api/*`・`/health`、TTL 0）。geo restriction は JP のみ。viewer は `redirect-to-https` | IaC | 描く | request-flow, operations | `terraform/modules/cloudfront/main.tf:15-163` |
| CloudFront origin access control（OAC） | — | S3 origin への署名付きアクセス | 管理外（data source で参照） | ラベル（CloudFront → S3 の線に「OAC」） | request-flow | `terraform/modules/cloudfront/main.tf:5-7,31` |
| AWS WAF | — | 無い | — | 描かない（現行環境に存在しない。ADR 0002 で無効を受け入れ） | — | `terraform/` に `aws_wafv2_*` が 0 件 |
| AWS Identity and Access Management（IAM） | `aws_iam_openid_connect_provider.github` | GitHub Actions の OIDC federation | IaC（foundation） | ラベル（GitHub Actions → STS の線に「OpenID Connect」） | operations | `terraform/foundation/iam.tf:11-12` |
| IAM role | `aws_iam_role.hannibal_cicd_role`（trust policy の subject は main ブランチ） | deploy / destroy が assume する | IaC（foundation） | 描かない（role は線のラベル「AssumeRoleWithWebIdentity」で足りる。個々の role を描くと権限設計の図になり、構成図の範囲を超える） | — | `terraform/foundation/iam.tf:47-70`、`deploy.yml:34` |
| IAM role | `aws_iam_role.hannibal_pr_plan_role` | PR plan 用。Issue #410 で PR plan を停止しており、どの workflow も使わない | IaC（foundation） | 描かない（定義のみで現行の通信に使われない） | — | `terraform/foundation/iam.tf:1009-1030`、`docs/operations/pr-terraform-plan-role-design.md:181` |
| IAM role | `aws_iam_role.hannibal_developer_role`、`aws_iam_role.hannibal_foundation_role`、Permission Boundary 群 | 人の操作・foundation の手動 apply 用 | IaC（foundation） | 描かない（人の権限分離で、構成の通信ではない。README 本文で `docs/operations/iam-management.md` を参照） | — | `terraform/foundation/iam.tf:20,1647-1668` |
| IAM role | `aws_iam_role.ecs_task_execution_role` | ECS の task execution role（image pull・ログ送信・secret の注入） | IaC | 描かない（ECS → ECR / Secrets Manager / CloudWatch Logs の線が task execution role の通信であることを凡例ではなく README 本文で示す） | — | `terraform/modules/ecs/iam.tf`、`terraform/modules/ecs/main.tf:56` |
| IAM role | CodeDeploy の service role、canary の実行 role、`aws_iam_role.hannibal_fis_role`、`aws_iam_role.cloudtrail_cloudwatch_logs_role` | 各サービスが使う role | IaC | 描かない（同上。各サービスの線で足りる） | — | `terraform/modules/codedeploy/main.tf`、`terraform/modules/synthetics/main.tf:43-118`、`terraform/foundation/iam.tf:1744,1806-1879` |
| ECS task role | — | 無い（アプリは AWS SDK を使わない） | — | 描かない（存在しない） | — | `terraform/modules/ecs/main.tf:62`（コメントアウト） |
| AWS Security Token Service（AWS STS） | — | `AssumeRoleWithWebIdentity` で一時認証情報を発行 | AWS の control plane | 描く | operations | `.github/workflows/deploy.yml:26-35` |

### Region: ap-northeast-1 — VPC

| サービス名 | リソース名 | 役割 | 管理方法 | 作図 | 観点 | 根拠 |
| --- | --- | --- | --- | --- | --- | --- |
| Amazon VPC | `aws_vpc.main` | 3 層（public / app / data）の VPC | IaC（network） | 描く（枠） | request-flow, operations, network | `terraform/modules/vpc/main.tf:5` |
| public subnet | `aws_subnet.public`（2 AZ） | ALB と NAT gateway | IaC | 描く（枠） | request-flow, operations, network | `terraform/modules/vpc/main.tf:30-48` |
| private subnet（app） | `aws_subnet.app`（2 AZ） | ECS task | IaC | 描く（枠） | request-flow, operations, network | `terraform/modules/vpc/main.tf:50-67` |
| private subnet（data） | `aws_subnet.data`（2 AZ）、`aws_db_subnet_group.postgres` | RDS。route table にデフォルトルートが無い | IaC | 描く（枠） | request-flow, operations, network | `terraform/modules/vpc/main.tf:69-85`、`terraform/modules/vpc/nat.tf:86-96`、`terraform/modules/rds/main.tf:10-19` |
| internet gateway | `aws_internet_gateway.main` | public route table のデフォルトルートの宛先 | IaC | 描く | network | `terraform/modules/vpc/main.tf:18`、`terraform/modules/vpc/nat.tf:46-52` |
| NAT gateway | `aws_nat_gateway.main`（dev は AZ 1a に 1 台で 2 AZ 共用）+ `aws_eip.nat` | app subnet から外への通信（AWS の API を含む） | IaC | 描く | network | `terraform/modules/vpc/nat.tf:4-42,62-83` |
| route table | `aws_route_table.public` / `app` / `data` | 経路 | IaC | 描かない（NAT gateway・internet gateway への線で示す） | — | `terraform/modules/vpc/nat.tf:46-120` |
| security group | `aws_security_group.alb` / `ecs` / `rds` | ALB は CloudFront の origin-facing managed prefix list からだけ受ける。ECS は ALB の SG から、RDS は ECS の SG から | IaC | ラベル（線のラベルと README 本文。枠で描かない） | network | `terraform/modules/vpc/security_groups.tf:1-75` |
| VPC endpoint | — | 無い。AWS の API への通信はすべて NAT gateway 経由 | — | 描かない（存在しない） | — | `terraform/` に `aws_vpc_endpoint` が 0 件 |
| Application Load Balancer | `aws_lb.main`（internet-facing） | HTTPS:443 の production listener。origin-verify の custom header が一致しなければ listener rule が 403 | IaC（service） | 描く | request-flow, operations, network | `terraform/modules/load-balancer/main.tf:1-206` |
| ALB の HTTP:80 listener | `aws_lb_listener.http` | HTTPS へ 301 redirect | IaC | 描かない（CloudFront の origin は `https-only` で、この listener を使う通信が構成上ない） | — | `terraform/modules/load-balancer/main.tf:12-25`、`terraform/modules/cloudfront/main.tf:46-53` |
| ALB の test listener（HTTPS:8080） | `aws_lb_listener.test` | CodeDeploy の test traffic route | IaC | 描かない（test traffic を流す hook・利用者が無い。CodeDeploy の listener 切り替えの線のラベルに含める） | — | `terraform/modules/load-balancer/main.tf:64-89`、`terraform/modules/codedeploy/main.tf:105-112` |
| ALB target group | `aws_lb_target_group.blue` / `green`（target type ip、HTTP:3000、health check `/health`） | Blue/Green デプロイ用 | IaC | ラベル（ALB の要素に「target group: blue / green」） | operations | `terraform/modules/load-balancer/target_groups.tf` |
| Amazon Elastic Container Service（Amazon ECS） | `aws_ecs_cluster.main`、`aws_ecs_service.api`（launch type FARGATE、`deployment_controller = CODE_DEPLOY`、desired count 1、`assign_public_ip = false`）、`aws_ecs_task_definition.api`（コンテナ 1 つ） | NestJS + GraphQL API。起動時に TypeORM の migration を適用する | IaC（service） | 描く（1 要素。cluster の枠は作らない: 中身が service 1 つ） | request-flow, operations, network | `terraform/modules/ecs/main.tf:42-161`、`terraform/service/variables.tf:30-34` |
| Amazon RDS for PostgreSQL | `aws_db_instance.postgres`（engine postgres、Single-AZ、暗号化、`publicly_accessible = false`、IAM database authentication は有効だがアプリは未使用） | アプリの DB（`routes` テーブル）。Aurora ではない | IaC（database） | 描く | request-flow, operations, network | `terraform/modules/rds/main.tf:24-60`、`terraform/database/variables.tf` |
| RDS の automated backups | `backup_retention_period`（dev は 7 日）。final DB snapshot なし（`skip_final_snapshot = true`）、deletion protection なし | マネージドのバックアップ。保存先は RDS が管理する（利用者の S3 bucket ではない） | IaC | ラベル（RDS の要素に「automated backups 保持 7 日」。S3・AWS Backup への線は引かない） | operations | `terraform/modules/rds/main.tf:3,6,46,54-55` |

### Region: ap-northeast-1 — VPC の外

| サービス名 | リソース名 | 役割 | 管理方法 | 作図 | 観点 | 根拠 |
| --- | --- | --- | --- | --- | --- | --- |
| Amazon Elastic Container Registry（Amazon ECR） | private repository | API のコンテナイメージ | 管理外（repository は手動作成。IaC 管理は `aws_ecr_lifecycle_policy` の最新 10 個保持だけ） | 描く | operations | `terraform/modules/ecs/main.tf:18-37`、`docs/operations/manual-resources.md:63-74` |
| AWS Secrets Manager | RDS が管理する master user secret（`manage_master_user_password`） | DB のユーザー名・パスワード | IaC（RDS が自動作成） | 描く | operations | `terraform/modules/rds/main.tf:37`、`terraform/modules/ecs/main.tf:100-104` |
| Amazon CloudWatch Logs | `aws_cloudwatch_log_group.ecs_api_task_logs`（保持 7 日） | ECS のアプリログ | IaC | 描く | operations | `terraform/modules/ecs/main.tf:105-124` |
| Amazon S3（frontend） | frontend 用 bucket（bucket 本体は手動作成）。IaC 管理は `aws_s3_bucket_policy`（`cloudfront.amazonaws.com` + SourceArn 条件）、public access block、`aws_s3_object.frontend_files` | React のビルド成果物 | 管理外（bucket）/ IaC（policy・object） | 描く | request-flow, operations | `terraform/modules/s3/main.tf:1-74` |
| AWS Certificate Manager（ACM） | ALB 用の証明書 | ALB の HTTPS listener の TLS | 管理外（ARN を GitHub Variables で渡す） | ラベル（ALB の要素に「ACM 証明書」） | request-flow | `terraform/modules/load-balancer/variables.tf:44`、`deploy.yml:187` |
| AWS CodeDeploy | `aws_codedeploy_app.main`、`aws_codedeploy_deployment_group.main`（BLUE_GREEN。deployment config は `deployment_type` で canary = `ECSCanary10Percent5Minutes`、bluegreen = `ECSAllAtOnce`。DEPLOYMENT_FAILURE と DEPLOYMENT_STOP_ON_ALARM で auto rollback） | ECS の Blue/Green 切り替え | IaC（service） | 描く | operations | `terraform/modules/codedeploy/main.tf:35-139` |
| Amazon S3（CodeDeploy 用） | `aws_s3_bucket.codedeploy_artifacts` | deploy.yml が生成した AppSpec の置き場 | IaC | 描く | operations | `terraform/modules/codedeploy/main.tf:6-32`、`deploy.yml:306-321` |
| Amazon CloudWatch（alarm） | `aws_cloudwatch_metric_alarm` 12 個: ECS 3（CPU・Memory・RunningTaskCount）、RDS 2（CPUUtilization・DatabaseConnections）、ALB の SLO burn-rate 4、ALB の 5XX・TargetResponseTime 2（CodeDeploy の auto rollback 用）、Synthetics の `SuccessPercent` 1 | 監視。alarm action はすべて SNS topic `aws_sns_topic.alerts` | IaC（service） | 描く（まとめて 1 要素。評価対象はラベル「対象: ECS・RDS・ALB・canary」） | operations | `terraform/modules/monitoring/main.tf:23-403` |
| Amazon CloudWatch（dashboard） | `aws_cloudwatch_dashboard.main` | ECS / RDS / ALB の metric | IaC | ラベル（CloudWatch alarm と同じ要素に「dashboard」） | operations | `terraform/modules/monitoring/main.tf:406-490` |
| Amazon SNS | `aws_sns_topic.alerts` + email subscription | alarm の通知先 | IaC（service。destroy で消える） | 描く | operations | `terraform/modules/monitoring/main.tf:5-19` |
| email（SNS の subscription の endpoint） | — | 通知の受け手（宛先は書かない） | — | 描く | operations | 同上 |
| Amazon CloudWatch Synthetics | `aws_synthetics_canary.user_journey`（`rate(5 minutes)`、VPC 設定なし = VPC の外の Lambda として動く） | CloudFront 経由で frontend → `/health` → GraphQL `capitalCities` → GraphQL `routes`（DB を通る）を確認する外形監視。deploy 後の確認にも使う | IaC（service） | 描く | operations | `terraform/modules/synthetics/main.tf:142-170`、`terraform/service/main.tf:89-108`、`terraform/service/variables.tf:102-130` |
| Amazon S3（canary 用） | `aws_s3_bucket.canary_artifacts` | canary のコードと実行結果 | IaC | 描く | operations | `terraform/modules/synthetics/main.tf:11-41,127-147` |
| AWS Fault Injection Service（AWS FIS） | `aws_fis_experiment_template.ecs_task_stop`（`aws:ecs:stop-task`、stop condition は SLO error-rate fast-burn alarm） | Game Day 演習 | IaC（observability。`continue-on-error` で apply） | 描く | operations | `terraform/modules/fis/main.tf:8-40`、`terraform/observability/main.tf:22-32`、`deploy.yml:199-220` |
| Amazon S3（Terraform state） | backend の state bucket | 全 root module の state | 管理外 | 描かない（Terraform の backend で、アプリの構成ではない。README 本文で触れる） | — | `terraform/*/backend.tf`、`terraform/service/main.tf:1-19` |
| Application Auto Scaling | — | 無い | — | 描かない（存在しない） | — | `terraform/` に `aws_appautoscaling_*` が 0 件 |
| AWS X-Ray | — | canary の実行 role に `xray:PutTraceSegments` の権限はあるが、canary の `run_config` に active tracing の設定が無い | — | 描かない（権限だけで、送信の設定が無い） | — | `terraform/modules/synthetics/main.tf:100-102,155-165` |
| AWS Backup・手動 DB snapshot・クロスリージョン複製 | — | 無い | — | 描かない（存在しない） | — | `terraform/` に `aws_backup_*`・`aws_db_snapshot` が 0 件 |
| pg_dump → S3 のバックアップ | — | docs の例だけ | — | 描かない（手順書のみ） | — | `docs/architecture/data-architecture.md:542-559` |
| standalone task による `migration:revert` | — | schema の rollback 手順 | — | 描かない（手順書のみ。README 本文で触れる） | — | `docs/operations/runbook.md:263-301` |
| Amazon GuardDuty | — | コメントアウト済み | — | 描かない（存在しない） | — | `terraform/foundation/guardduty.tf`（resource が 0 件） |

### Region: ap-northeast-1 — foundation の監査系（アカウント全体、destroy 後も残る）

| サービス名 | リソース名 | 役割 | 管理方法 | 作図 | 観点 | 根拠 |
| --- | --- | --- | --- | --- | --- | --- |
| AWS CloudTrail | `aws_cloudtrail.hannibal_trail`（single-Region、`is_multi_region_trail = false`、`include_global_service_events = true`）+ S3 bucket（365 日で失効）+ log group（保持 30 日） | API 呼び出しの監査ログ | IaC（foundation） | 描く（CloudTrail・S3（CloudTrail 用）・CloudWatch Logs（CloudTrail 用）を別の要素にする。log group は ECS 用と保持が違うので分ける） | operations | `terraform/foundation/cloudtrail.tf:3-53,96-127`、`terraform/foundation/cloudwatch.tf:41-43` |
| Amazon CloudWatch（セキュリティ監視） | metric filter 4 + alarm 4（root の利用、IAM policy の変更、CloudTrail の設定変更、MFA なしの console sign-in） | セキュリティ通知 | IaC（foundation） | 描く（alarm は既存の Amazon CloudWatch の要素にまとめ「alarm ×16」「対象: …・CloudTrail」。metric filter は CloudWatch Logs（CloudTrail 用）のラベル「metric filter ×4」） | operations | `terraform/foundation/cloudwatch.tf:41-112` |
| Amazon SNS（セキュリティ用） | セキュリティ alarm 用の topic + email subscription | 通知先 | IaC（foundation） | 描く（既存の Amazon SNS の要素にまとめ「topic ×2」。alarm → SNS → email の線を共用） | operations | `terraform/foundation/cloudwatch.tf:55-72` |
| Amazon Athena / AWS Glue Data Catalog | `aws_athena_workgroup`、`aws_athena_database`、`aws_glue_catalog_table`、named query 3、結果用 S3 bucket | CloudTrail ログの分析（人が query を実行） | IaC（foundation） | 描く（Athena と S3（Athena の結果用）。AWS Glue Data Catalog は描かない） | operations | `terraform/foundation/athena.tf:3-288` |
| AWS Budgets | `aws_budgets_budget.monthly_cost`（閾値 4、email 通知） | コスト通知 | IaC（foundation） | 描かない（アカウントの課金設定で、構成の通信ではない。README 本文で触れる） | — | `terraform/foundation/billing.tf:4-40` |

**監査系の提案:** README の冒頭（`README.md:8`）が CloudTrail / Athena を管理対象に挙げているので、図から完全に消すより、別の観点 `security-audit` に分けるのを第一案にする。operations に入れると、アプリのデプロイ・監視（destroy で消える）とアカウント全体の監査（永続）が同じ図に混ざり、SNS topic が 2 つ並んで紛らわしい。→ 2026-11-14 ユーザー決定で operations に入れた（`security-audit` は立てない。SNS topic は 1 要素「topic ×2」にまとめる。「突き合わせで解消した点」を参照）。

### Region: us-east-1

| サービス名 | リソース名 | 役割 | 管理方法 | 作図 | 観点 | 根拠 |
| --- | --- | --- | --- | --- | --- | --- |
| AWS Certificate Manager（ACM） | CloudFront 用の証明書 | CloudFront の viewer certificate（SNI） | 管理外（ARN を GitHub Variables で渡す） | 要判断 | request-flow | `terraform/modules/cloudfront/main.tf:187-192`、`terraform/cdn/variables.tf:36`、`deploy.yml:230` |
| CloudFront 用の CloudWatch alarm・AWS WAF | — | 無い（us-east-1 の provider も無い） | — | 描かない（存在しない） | — | `terraform/*/provider.tf` |

---

## 接続関係

向きは「通信を開始する側 → 受ける側」。応答は描かない。番号は request-flow の主要な流れ（後述）。

| # | 通信元 | 通信先 | プロトコル・方式 | 目的 | 作図 | 観点 | 根拠 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| — | ブラウザ | Route 53 | DNS（alias record で CloudFront の address を返す） | 名前解決 | 描く（番号なし） | request-flow | `terraform/modules/dns/route53.tf:2-14` |
| ① | ブラウザ | CloudFront | HTTPS（HTTP は `redirect-to-https`、TLSv1.2_2021） | 静的ファイル（index.html・JS。mapbox-gl の chunk を含む）の取得 | 描く | request-flow | `terraform/modules/cloudfront/main.tf:56-84,187-192`、`client/src/components/MapContainer.tsx:89` |
| ② | CloudFront | S3（frontend） | HTTPS、OAC（SigV4 署名）。bucket policy で `s3:GetObject` を distribution に限定 | cache miss 時の origin request。403 / 404 は index.html を返す | 描く | request-flow | `terraform/modules/cloudfront/main.tf:25-32,154-163`、`terraform/modules/s3/main.tf:53-74`、<https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-https-cloudfront-to-s3-origin.html> |
| ③ | ブラウザ | CloudFront | JSON/HTTPS（Apollo Client の `HttpLink`、同一オリジンの `/graphql`） | 地図データの取得（GraphQL query `GetMapData`: `capitalCities`・`hannibalRoute`・`pointRoute`） | 描く | request-flow | `client/src/components/MapContainer.tsx:31-81`、`client/src/apollo/client.ts:5-21`、`deploy.yml:146` |
| ④ | CloudFront | ALB | HTTPS:443（`https-only`、TLSv1.2）。origin の domain は Route 53 の `api.` alias record。custom header で origin を検証 | GraphQL リクエストの転送（`/graphql` behavior、TTL 0） | 描く | request-flow | `terraform/modules/cloudfront/main.tf:34-54,126-144`、`terraform/modules/dns/route53.tf:18-30`、`terraform/modules/load-balancer/main.tf:93-206` |
| ⑤ | ALB | ECS task | HTTP:3000（ALB の SG → ECS の SG、target type ip） | GraphQL リクエストの転送 | 描く | request-flow | `terraform/modules/load-balancer/target_groups.tf`、`terraform/modules/vpc/security_groups.tf:34-40` |
| ⑥ | ブラウザ | Mapbox | HTTPS（mapbox-gl。public access token） | 地図タイルの取得（style・地形データを含む）。GraphQL の結果が届いた後に地図を初期化する | 描く | request-flow | `client/src/components/MapContainer.tsx:114-126`、`client/src/services/mapSetup.ts:38-43,67-75` |
| — | ECS task | RDS | PostgreSQL protocol/TLS（TCP 5432、`sslmode=require`、RDS CA bundle、パスワード認証） | `routes` query・migration の実行。**③〜⑤ の `GetMapData` は DB を使わない**（resolver はアプリに同梱の GeoJSON を返す） | 描く（番号なし） | request-flow, operations, network | `terraform/modules/vpc/security_groups.tf:62-68`、`terraform/modules/ecs/main.tf:92-98`、`src/database/typeorm-options.ts:18-26,36,48`、`src/modules/route/route.service.ts:91-113`、`src/modules/map/map.service.ts:9-11` |
| — | インターネット（CloudFront の origin-facing アドレス以外） | ALB | security group で拒否。header が無ければ listener rule が 403 | ALB への直接アクセスの防止（ADR 0004） | 描かない（README 本文） | — | `terraform/modules/vpc/security_groups.tf:6-12`、`terraform/modules/load-balancer/main.tf:166-206` |
| — | ALB | ECS task | HTTP の health check（`/health`、CloudFront を経由しない。アプリは認証なしで 200） | target の健全性確認 | 描かない（README 本文。⑤ と同じ 2 点間で線が重なる） | — | `terraform/modules/load-balancer/target_groups.tf`、`src/app.setup.ts:53-55` |
| — | ECS（Fargate の agent、task execution role） | ECR | image pull（NAT gateway 経由） | コンテナイメージの取得 | 描く | operations | `terraform/modules/ecs/main.tf:69`、`terraform/modules/ecs/iam.tf:21-24` |
| — | ECS（Fargate の agent、task execution role） | Secrets Manager | `GetSecretValue`。task の起動時に `DB_USER` / `DB_PASSWORD` を注入 | DB の認証情報 | 描く | operations | `terraform/modules/ecs/main.tf:100-104`、`terraform/modules/ecs/iam.tf:26-46` |
| — | ECS（`awslogs` log driver） | CloudWatch Logs | task execution role | アプリログ（TypeORM の error・schema・migration を含む） | 描く | operations | `terraform/modules/ecs/main.tf:105-112`、`src/database/typeorm-options.ts:52` |
| — | ECS task（app subnet） | NAT gateway → internet gateway | 0.0.0.0/0 の経路 | 外向きの通信（ECR・Secrets Manager・CloudWatch Logs の API） | 描く | network | `terraform/modules/vpc/nat.tf:62-83` |
| — | RDS（data subnet） | — | デフォルトルートなし | 外へ出ない | 描かない（線が無いことで示す。README 本文） | — | `terraform/modules/vpc/nat.tf:86-96` |
| — | 人（GitHub の UI） | GitHub Actions | `workflow_dispatch` | deploy / destroy の開始 | 描かない（GitHub Actions のラベル「手動実行」で足りる） | — | `deploy.yml:8-19` |
| — | GitHub Actions | AWS STS | `AssumeRoleWithWebIdentity`（OpenID Connect。trust policy は main ブランチ） | 一時認証情報の取得 | 描く | operations | `deploy.yml:26-35`、`terraform/foundation/iam.tf:47-70` |
| — | GitHub Actions | 各 root module のリソース | `terraform apply`（network → database → service → observability → cdn） | インフラの作成・更新 | 描く（GitHub Actions → Region 枠への 1 本にまとめる） | operations | `deploy.yml:150-236` |
| — | GitHub Actions | S3（frontend） | `aws s3 sync --delete`（cdn の apply の `aws_s3_object` でも配置） | 静的ファイルの配置 | 描く | operations | `deploy.yml:238-242`、`terraform/modules/s3/main.tf:21-49` |
| — | GitHub Actions | CloudFront | `create-invalidation /*` | キャッシュの無効化 | 描く | operations | `deploy.yml:243-246` |
| — | GitHub Actions | ECR | `docker push`（コミット SHA タグと `latest`） | イメージの登録 | 描く | operations | `deploy.yml:253-273` |
| — | GitHub Actions | ECS | `register-task-definition`、古い revision の deregister | task definition の更新 | 描く | operations | `deploy.yml:275-303,376-418` |
| — | GitHub Actions | S3（CodeDeploy 用） | `aws s3 cp`（AppSpec） | AppSpec の配置 | 描く | operations | `deploy.yml:306-311` |
| — | GitHub Actions | CodeDeploy | `create-deployment` → `wait deployment-successful`（canary / bluegreen モード。provisioning モードは実行しない） | Blue/Green デプロイの開始 | 描く | operations | `deploy.yml:306-339` |
| — | CodeDeploy | S3（CodeDeploy 用） | AppSpec の取得（`--s3-location`） | デプロイ定義の読み込み | 描く | operations | `deploy.yml:312-316` |
| — | CodeDeploy（service role） | ECS | replacement task set の作成・旧 task set の終了 | Blue/Green 切り替え | 描く | operations | `terraform/modules/codedeploy/main.tf:76-112` |
| — | CodeDeploy（service role） | ALB | production / test listener の forward 先の切り替え（blue / green target group） | トラフィックの移行 | 描く | operations | `terraform/modules/codedeploy/main.tf:95-112` |
| — | CodeDeploy | CloudWatch alarm | alarm の状態を参照（ALB の 5XX・TargetResponseTime の 2 個） | alarm で停止・auto rollback | 描く | operations | `terraform/modules/codedeploy/main.tf:121-131` |
| — | CloudWatch alarm | 評価対象（ECS・RDS・ALB・canary の metric） | metric の評価 | 監視 | ラベル（矢印にしない） | operations | `terraform/modules/monitoring/main.tf:23-403` |
| — | CloudWatch alarm | SNS topic | alarm action / ok action | 通知 | 描く | operations | `terraform/modules/monitoring/main.tf:33-34` ほか各 alarm |
| — | SNS topic | email | email subscription（宛先は書かない） | 通知 | 描く | operations | `terraform/modules/monitoring/main.tf:15-19` |
| — | Synthetics canary（VPC の外） | CloudFront | HTTPS。frontend → `/health` → GraphQL `capitalCities` → GraphQL `routes` | 外形監視（終点は CloudFront。ALB 直ではない） | 描く | operations | `terraform/service/main.tf:86-103`、`terraform/modules/synthetics/canary-src/nodejs/node_modules/apiCanary.js:94-123` |
| — | Synthetics canary | S3（canary 用） | `s3:PutObject` | 実行結果の保存 | 描く | operations | `terraform/modules/synthetics/main.tf:65-80,144` |
| — | Synthetics canary | CloudWatch | `cloudwatch:PutMetricData`（namespace CloudWatchSynthetics） | `SuccessPercent` などの metric | 描く | operations | `terraform/modules/synthetics/main.tf:107-114` |
| — | Synthetics canary | CloudWatch Logs | `logs:PutLogEvents` | canary のログ | 描かない（canary → CloudWatch の 1 本にまとめる） | — | `terraform/modules/synthetics/main.tf:88-96` |
| — | Synthetics canary | X-Ray | — | — | 描かない（active tracing の設定が無い） | — | `terraform/modules/synthetics/main.tf:155-165` |
| — | GitHub Actions | CloudWatch Synthetics | `GetCanaryRuns`（読むだけ） | deploy 後の確認 | 描く | operations | `deploy.yml:341-374`、`scripts/deployment/wait-for-synthetics-canary.sh` |
| — | 開発者端末 | AWS FIS | `fis:StartExperiment`（手動） | Game Day の開始 | 描く | operations | `scripts/game-day/run-ecs-task-stop-experiment.sh:96` |
| — | AWS FIS | ECS | `aws:ecs:stop-task` | task の停止 | 描く | operations | `terraform/modules/fis/main.tf:17-36` |
| — | AWS FIS | CloudWatch alarm | stop condition（SLO error-rate fast-burn alarm の状態を参照） | 実験の停止条件 | 描く | operations | `terraform/modules/fis/main.tf:12-15`、`terraform/observability/main.tf:32` |
| — | RDS | （RDS が管理する保存先） | automated backups | バックアップ | ラベル（線を引かない） | operations | `terraform/modules/rds/main.tf:46` |
| — | GitHub Actions（destroy.yml） | CodeDeploy・ECS・各 root module・S3・ECR・ALB | deployment の停止、desired count 0、`terraform destroy`、best-effort の後始末 | 環境の削除 | 描かない（README 本文。deploy と同じ線が重なる） | — | `destroy.yml:7-176` |
| — | CloudTrail | S3（CloudTrail 用）・CloudWatch Logs → metric filter → alarm → SNS（セキュリティ用）→ email | サービス連携（専用 role） | 監査とセキュリティ通知 | 描く（CloudTrail → S3・CloudWatch Logs は「ログの配信」の線。metric filter は線にせずラベル。alarm → SNS → email は既存の線を共用） | operations | `terraform/foundation/cloudtrail.tf:96-127`、`terraform/foundation/cloudwatch.tf:41-112` |
| — | Athena | S3（CloudTrail 用・結果用） | ログの読み取り・結果の書き込み | 監査の分析 | 描く（Athena → S3（CloudTrail 用）「ログの分析」、Athena → S3（Athena の結果用）「クエリ結果の保存」） | operations | `terraform/foundation/athena.tf:3-66,79-114` |
| — | コンテナイメージの build | RDS の truststore（AWS 外の公開エンドポイント） | HTTPS（build 時だけ） | RDS CA bundle の取得 | 描かない（実行時の構成ではない） | — | `Dockerfile:23-26` |

---

## 観点の案

| 観点名 | タイトル | 含める要素 | 番号を振る流れ | この観点を立てる理由 |
| --- | --- | --- | --- | --- |
| `request-flow` | 地図表示のリクエストの流れ | ブラウザ、Mapbox、Route 53、CloudFront、ACM（要判断）、S3（frontend）、ALB、ECS、RDS。枠は AWS Cloud・Region・VPC・subnet 3 種 | ①〜⑥（下記）。ECS → RDS は番号なしの線 | README の読者が最初に知りたい「サイトを開いてから地図が出るまで」を 1 枚で示す |
| `operations` | デプロイ・監視・監査・Game Day・バックアップ | GitHub Actions、AWS STS、ECR、Secrets Manager、CloudWatch Logs、S3（frontend・CodeDeploy 用・canary 用）、CloudFront、CodeDeploy、ALB、ECS、RDS（automated backups のラベル）、CloudWatch alarm / dashboard、SNS、email、Synthetics canary、AWS FIS、開発者端末、（2026-11-14 追加）AWS CloudTrail、S3（CloudTrail 用・Athena の結果用）、CloudWatch Logs（CloudTrail 用）、Amazon Athena | 番号なし（deploy の手順は README 本文の番号付きリストで書く。線が多く番号を振ると図が読みにくい） | デプロイの経路（OIDC → apply → push → CodeDeploy → canary の確認）と、監視・通知・Game Day・バックアップの設計を示す |
| `network` | ネットワーク構成 | VPC、AZ 2 つ（1a / 1c）、public / app / data subnet、internet gateway、NAT gateway（1a に 1 台）、ALB、ECS、RDS、CloudFront | 番号なし | 3 層の subnet、data subnet が外へ出ない構成、NAT gateway 1 台の共用、VPC endpoint が無く AWS の API が NAT gateway 経由であること、SG の連鎖（CloudFront の prefix list → ALB → ECS → RDS）を示す。request-flow には AZ を描かない |
| `security-audit`（不採用。2026-11-14 ユーザー決定で operations に統合） | 監査とセキュリティ通知 | CloudTrail、S3（CloudTrail 用・Athena 結果用）、CloudWatch Logs、CloudWatch alarm（セキュリティ用）、SNS（セキュリティ用）、email、Athena / Glue Data Catalog | 番号なし | foundation の常設の監査系（destroy 後も残る）を、destroy で消えるアプリ系と分けて示す |

### request-flow の番号（client の処理順）

1. ① ブラウザ → CloudFront: 静的ファイルの取得（`main.tsx` の読み込み）
2. ② CloudFront → S3: cache miss 時の origin request
3. ③ ブラウザ → CloudFront: GraphQL の `GetMapData`。`MapContainer` の mount 時に `useQuery` が送る（`client/src/components/MapContainer.tsx:81`）。同時に mapbox-gl の chunk を動的 import する（同 `:89`、① と同じ CloudFront → S3 の経路なので別番号にしない）
4. ④ CloudFront → ALB（`/graphql` behavior）
5. ⑤ ALB → ECS task。resolver は同梱の GeoJSON を返し、**DB には行かない**（`src/modules/route/route.service.ts:91-113`、`src/modules/map/map.service.ts:9-11`）
6. ⑥ ブラウザ → Mapbox: `data` が届き mapbox-gl の読み込みが終わってから `initializeMap` を呼び、style・tile・地形を取得する（`MapContainer.tsx:114-122`、`client/src/services/mapSetup.ts:38-43,67-75`）

依頼の想定「GraphQL でルート取得 → DB」は、現行コードでは成り立たない。DB を通る GraphQL `routes` は client から呼ばれず、canary と test だけが使う（`terraform/service/variables.tf:120-124`、`client/src` に `routes` の query が無い）。

---

## グループ枠の案

| 枠名 | 型 / 実体 | 中に置くもの | 観点 | 根拠 |
| --- | --- | --- | --- | --- |
| `AWS Cloud` | AWS Architecture Icons のグループ（`group_aws_cloud`） | Region 枠、CloudFront、Route 53、AWS STS | 全観点 | aws.md「グループ枠」 |
| `Region: ap-northeast-1` | Region のグループ | VPC、ECR、Secrets Manager、CloudWatch、SNS、CodeDeploy、S3 bucket 群、Synthetics canary、AWS FIS、CloudTrail・Athena（operations）| 全観点 | 全 `terraform/*/provider.tf` の `region` |
| `Region: us-east-1` | Region のグループ | CloudFront 用の ACM 証明書だけ（要判断。中身が 1 つ） | request-flow | `terraform/modules/cloudfront/main.tf:188`、aws.md「CloudFront 用の ACM 証明書は `Region: us-east-1` の枠」 |
| `VPC` | VPC のグループ（`group_vpc2`） | subnet 3 種 | request-flow, operations, network | `terraform/modules/vpc/main.tf:5` |
| `Availability Zone` | AZ のグループ | 各 AZ の subnet | network だけ | `terraform/modules/vpc/main.tf:32-33,52-53,71-72` |
| `Public subnet (2 AZs)` | public subnet のグループ | ALB、NAT gateway（network 図では 1a だけ） | request-flow, operations, network | `terraform/modules/vpc/main.tf:30-48` |
| `Private subnet (app, 2 AZs)` | private subnet のグループ | ECS | request-flow, operations, network | `terraform/modules/vpc/main.tf:50-67`（IaC 名 `app`） |
| `Private subnet (data, 2 AZs)` | private subnet のグループ | RDS（Single-AZ） | request-flow, operations, network | `terraform/modules/vpc/main.tf:69-85`（IaC 名 `data`） |

作らない枠: `Amazon ECS cluster (AWS Fargate)`（中身が service 1 つだけ。ECS のアイコンのラベルに「AWS Fargate」を添える）、CloudFront 用の枠、CI/CD・監視などの機能の枠、security group の枠、AWS Account 枠（単一アカウント）。network の図では AZ 枠の中に subnet を描くので、subnet 名の「(2 AZs)」は外す。

---

## 突き合わせで解消した点

- 2026-11-14 ユーザー決定で operations に追加: foundation の監査系（AWS CloudTrail、S3（CloudTrail 用）、CloudWatch Logs（CloudTrail 用）、Amazon Athena、S3（Athena の結果用）、セキュリティ用の metric filter・alarm・SNS topic）。全体図にも同じ要素・線を描く。観点 `security-audit` は立てない。AWS Glue Data Catalog と AWS Budgets は描かない

| 論点 | 担当間の差 | 結論と根拠 |
| --- | --- | --- |
| 主要な流れで DB を通るか | インフラは ECS → RDS を「アプリのデータ」とし、データ運用は seed の流れを「クライアント → ECS → RDS」と書いた。どちらもブラウザの地図表示が DB を使うかを明示していない | **使わない。** client の唯一の query `GetMapData` は `capitalCities`・`hannibalRoute`・`pointRoute` で、resolver は同梱の GeoJSON を返す（`client/src/components/MapContainer.tsx:31-81`、`src/modules/route/route.resolver.ts:69-81`、`src/modules/route/route.service.ts:91-113`、`src/modules/map/map.service.ts:9-11`）。ECS → RDS は番号の外の線にする |
| CloudWatch alarm の数 | インフラは 13 個、データ運用は内訳の合計 12 個 | **service の alarm は 12 個**（`terraform/modules/monitoring/main.tf` の `aws_cloudwatch_metric_alarm` が 12）。ほかに foundation のセキュリティ用が 4 個（`terraform/foundation/cloudwatch.tf`） |
| 「canary 用 alarm」の意味 | データ運用は「canary 用 alarm 2 つ（CodeDeploy 用）」、インフラは「synthetics 1、CodeDeploy 連動 2」 | 2 種類の canary を区別する。`canary_error_rate` / `canary_response_time` は CodeDeploy の canary デプロイ用で ALB の metric を見る（`monitoring/main.tf:360-403`）。Synthetics canary の alarm は `synthetics_availability` の 1 個（`monitoring/main.tf:332-356`） |
| CodeDeploy の deployment config | インフラは `ECSCanary10Percent5Minutes` 固定、CI/CD はモードで切り替え | **モードで切り替え。** `deployment_type == "canary"` なら `ECSCanary10Percent5Minutes`、それ以外は `ECSAllAtOnce`（`terraform/modules/codedeploy/main.tf:80`）。provisioning モードは CodeDeploy の deployment を作らない（`deploy.yml:175-180,306,322`） |
| frontend の S3 に何を IaC で置くか | インフラは policy と public access block だけ、CI/CD は `aws_s3_object` も | **両方。** `aws_s3_object.frontend_files` が cdn の apply で配置し（`terraform/modules/s3/main.tf:21-49`）、その後 `aws s3 sync --delete` でも同期する（`deploy.yml:238-242`） |
| AppSpec のコンテナ名の不一致（インフラの不明点） | インフラはリポジトリの `appspec.yml` と task definition のコンテナ名の食い違いを不明とした | **リポジトリの `appspec.yml` は使われていない。** deploy.yml が現行の task definition からコンテナ名を読んで AppSpec を生成する（`deploy.yml:275-303`）。`appspec.yml` を参照する workflow・script・tf は無い |
| canary → X-Ray | インフラは canary（実行 role）→ X-Ray（`PutTraceSegments`）を接続に挙げた | **描かない。** IAM の権限だけで、`aws_synthetics_canary` の `run_config` に active tracing の設定が無い（`terraform/modules/synthetics/main.tf:100-102,155-165`） |
| PR plan 用 role が使われているか | CI/CD は「workflow から使われていない」、docs（`iam-management.md`）は「使用中」 | **使われていない。** `role-to-assume` は `deploy.yml:34` と `destroy.yml:27` の CICD role だけ |
| migration の根拠の行番号 | インフラは `typeorm-options.ts:34-47`、データ運用は `:40-55` | `migrationsRun: true` は `src/database/typeorm-options.ts:48`（説明コメントは `:36`） |
| RDS CA bundle の取得の行番号 | インフラは `Dockerfile:23-26`、データ運用は `:22-25` | `Dockerfile:23-26` |
| ALB の test listener（8080）の利用者（インフラの不明点） | インフラは誰が流すか不明とした | CodeDeploy の `test_traffic_route` に使われる（`terraform/modules/codedeploy/main.tf:108-112`）。test traffic を流す hook・利用者は無く、CloudFront は 443 だけ（`terraform/modules/cloudfront/main.tf:46-53`）。描かない |

---

## 不明点

| 項目 | 不明な理由 | 関連ファイル |
| --- | --- | --- |
| ALB の metric を見る alarm が実際に評価されているか | `LoadBalancer` dimension に ARN suffix ではなく ALB の full ARN を渡している。metric が一致せず常に `INSUFFICIENT_DATA` / `notBreaching` になっている可能性があり、CodeDeploy の auto rollback と FIS の stop condition の効き方に影響する。実環境を確認しないと決まらない（図には alarm → SNS の線として描き、効いているかは書かない） | `terraform/service/main.tf:79`、`terraform/modules/monitoring/variables.tf:33`、`terraform/modules/monitoring/main.tf:153-403` |
| destroy 時に RDS の automated backups が残るか | `delete_automated_backups` を指定しておらず、provider の既定値に依存する。docs にも記載が無い | `terraform/modules/rds/main.tf:24-60` |
| dev の backup window・maintenance window の時間帯 | IaC が `null`（AWS の既定に任せる） | `terraform/modules/rds/main.tf:51-52` |
| RDS（Single-AZ）が置かれる AZ | DB subnet group は 2 AZ で、`availability_zone` の指定が無い | `terraform/modules/rds/main.tf:10-19,24-60` |
| GitHub Variables（`AWS_REGION` など）の値 | repo の外にあり、問い合わせていない。provider と backend は ap-northeast-1 固定 | `deploy.yml:34-35`、`terraform/*/provider.tf` |
| `ecs_task_stopped` alarm の意図 | `RunningTaskCount > 0` で ALARM になり、名前と条件が逆に見える（図はまとめて描くので作図には影響しない） | `terraform/modules/monitoring/main.tf:73-94` |
| docs と IaC の食い違い（作図は IaC に従う） | `security-design.md` は deletion protection 有効、`operations/README.md` は dashboard 名・RDS 接続数の閾値が IaC と違う、`monitoring.md` は CloudTrail の log group の保持を 90 日とする（IaC は 30 日） | `docs/architecture/security-design.md:210-217`、`docs/operations/README.md:118-130`、`docs/operations/monitoring.md:128`、`terraform/foundation/cloudwatch.tf:43` |

---

## ユーザー判断が要る点

1. **request-flow で DB をどう扱うか。** 地図表示の 1 回分は DB を通らない。案: ECS → RDS を番号なしの線（「routes の取得・migration」）で描き、README 本文に「地図データはアプリ同梱の GeoJSON」と書く。代案: request-flow から RDS を外し、operations と network だけに描く
2. **foundation の監査系（CloudTrail / CloudWatch のセキュリティ alarm / SNS / Athena）。** 案: 別の観点 `security-audit` にする。代案: 描かずに README 本文だけで触れる。AWS Budgets はどちらでも描かない。→ 2026-11-14 ユーザー決定: operations（と全体図）に描く
3. **CloudFront 用 ACM 証明書と `Region: us-east-1` 枠。** aws.md は us-east-1 枠に入れるとするが、中身が証明書 1 つだけになり「中身が 1 つしかない枠は作らない」と衝突する。案: 描くなら枠を作り証明書だけを置く。代案: ACM は 2 つとも描かず、CloudFront・ALB のラベル（「TLS: ACM」）にとどめる
