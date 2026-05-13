# AWS リソース棚卸し — 永続リソースと一時リソース

## 運用前提

このプロジェクトは **人に見せるときだけ deploy、見せ終わったら destroy** する運用を基本とする。

- `terraform/environments/dev/` 配下のリソースは destroy 済みが通常状態
- 以下に示す永続リソースは destroy 後も残り続ける（意図的）
- destroy を実行しても永続リソースは削除されない

---

## 消してはいけないリソース（永続リソース）

### 手動管理（Terraform 管理外）

| リソース | 名前 | 残す理由 |
|---------|------|---------|
| S3 バケット | `nestjs-hannibal-3-terraform-state` | Terraform state と S3 lockfile の保存先。削除すると state が失われ復旧困難 |
| S3 バケット | `nestjs-hannibal-3-frontend` | フロントエンド静的ファイル。Terraform は data 参照のみでバケット本体は管理外 |
| DynamoDB テーブル | `terraform-state-lock` | Terraform DynamoDB lock の移行期間用。S3 lockfile 安定後に後続作業で削除可否を判断する |
| ECR リポジトリ | `nestjs-hannibal-3` | コンテナイメージの保存先。deploy 時にイメージ push が必要 |
| CloudFront OAC | `nestjs-hannibal-3-oac` | S3 フロントエンドバケットへのアクセス制御。CloudFront distribution が参照する |
| Route53 Hosted Zone | `hamilcar-hannibal.click` | DNS 管理。削除するとドメインが引けなくなる |
| ACM 証明書 | `hamilcar-hannibal.click`（us-east-1） | CloudFront 用 HTTPS 証明書。us-east-1 固定 |
| IAM Permission Boundary | `HannibalCICDBoundary` | CI/CD Role の権限上限。削除すると Role の attach が失敗する |
| IAM Permission Boundary | `HannibalECSBoundary` | ECS タスク実行 Role の権限上限 |

### Terraform foundation 管理（`terraform/foundation/`）

destroy しても自動削除されない（foundation は手動 apply/destroy が前提）。

| リソース | 名前 | 残す理由 |
|---------|------|---------|
| IAM OIDC Provider | `token.actions.githubusercontent.com` | GitHub Actions から AWS への認証基盤。削除すると deploy/destroy が失敗する |
| IAM Role | `HannibalCICDRole-Dev` | deploy/destroy workflow が assume する Role |
| IAM Role | `HannibalDeveloperRole-Dev` | 日常開発・アプリ運用用 Role。foundation apply には使わない |
| IAM Role | `HannibalDeveloperRole-Dev-candidate` | Developer Role 最小権限化の検証用 Role。検証後に削除する |
| IAM Role | `HannibalFoundationRole-Dev` | `terraform/foundation` の手動 apply 専用 Role |
| IAM Role | `HannibalCloudTrailCloudWatchLogsRole-Dev` | CloudTrail が CloudWatch Logs へ management events を配信するための Role |
| IAM Role | `HannibalPRPlanRole-Dev` | PR terraform plan 用 Role（read-only） |
| IAM Policy | `HannibalCICDPolicy-Dev` | CI/CD Role に attach 中のポリシー（実運用中） |
| IAM Policy | `HannibalCICDPolicy-Dev-Minimal` | 最小権限化検討用（未 attach） |
| IAM Policy | `HannibalFoundationPolicy-Dev` | foundation apply 用ポリシー |
| IAM Permission Boundary | `HannibalDeveloperBoundary-Dev-candidate` | Developer Role 最小権限化 candidate の権限上限。検証後に削除する |
| IAM Permission Boundary | `HannibalFoundationBoundary-Dev` | Foundation Role の権限上限 |
| IAM Permission Boundary | `HannibalCloudTrailCloudWatchLogsBoundary-Dev` | CloudTrail の CloudWatch Logs 配信 Role の権限上限 |
| IAM Permission Boundary | `HannibalPRPlanBoundary-Dev` | PR plan Role の read-only 権限上限 |
| IAM Policy | `HannibalPRPlanPolicy-Dev` | PR plan 用 read-only ポリシー |
| IAM Policy | `HannibalDeveloperPolicy-Dev` | Developer Role 用ポリシー。`Hannibal*` IAM / foundation state 操作は含めない |
| IAM Policy | `HannibalDeveloperPolicy-Dev-candidate` | Developer Role 最小権限化の検証用ポリシー。検証後に本体へ反映して削除する |
| S3 バケット | `nestjs-hannibal-3-cloudtrail-logs` | CloudTrail 監査ログの保存先。`prevent_destroy = true` 設定済み。`AWSLogs/` 配下は365日で自動削除（長期監査の正本。CIS Benchmark が1年を推奨） |
| S3 バケット | `nestjs-hannibal-3-athena-results` | Athena クエリ結果の出力先。`prevent_destroy = true` 設定済み |
| CloudTrail Trail | `nestjs-hannibal-3` | management events の監査ログ記録。`prevent_destroy = true` 設定済み |
| CloudWatch Logs Log Group | `/aws/cloudtrail/nestjs-hannibal-3` | CloudTrail management events の即時検知・初動調査用。30日保持（即時検知用途に十分、コスト削減。CIS Benchmark の1年推奨は長期監査の正本である S3 に対するもの） |
| CloudWatch Logs Metric Filters | `root-account-usage` / `iam-policy-change` / `cloudtrail-configuration-change` / `console-signin-without-mfa` | CloudTrail events からセキュリティ検知用メトリクスを作成 |
| CloudWatch Alarms | `nestjs-hannibal-3-cloudtrail-*` | root 使用、IAM ポリシー変更、CloudTrail 設定変更、MFA なしサインインを SNS 通知 |
| SNS Topic | `nestjs-hannibal-3-security-alerts` | CloudTrail セキュリティアラーム通知先。email subscription は確認メール承認が必要 |
| Athena Workgroup | `hannibal-cloudtrail-analysis` | CloudTrail 分析用。`prevent_destroy = true` 設定済み |
| Athena Database | `hannibal_cloudtrail_db` | CloudTrail 分析用論理 DB。`prevent_destroy = true` 設定済み |
| Glue Catalog Table | `cloudtrail_logs_partitioned` | Athena が CloudTrail 監査ログを読むための外部テーブル定義。`prevent_destroy = true` 設定済み |
| AWS Budgets | `aws-account-cost-*usd`（$5〜$200） | コスト超過アラート。削除するとコスト監視が止まる |

---

## destroyで消えるリソース（一時リソース）

`terraform destroy`（`destroy.yml` 経由）で削除される。通常は destroy 済み状態が前提。

| カテゴリ | リソース |
|---------|---------|
| ネットワーク | VPC、サブネット（Public/App/Data）、Internet Gateway、NAT Gateway、ルートテーブル |
| セキュリティ | Security Groups（ALB/ECS/RDS 用） |
| コンピュート | ECS Cluster、ECS Service |
| ロードバランサー | ALB、Target Groups（Blue/Green）、Listeners |
| データベース | RDS インスタンス、DB Subnet Group、Secrets Manager managed secret（RDS パスワード） |
| フロントエンド | CloudFront Distribution（バケット本体は永続。OAC も永続） |
| モニタリング | CloudWatch Log Groups、Alarms、Dashboards、SNS Topics |
| CI/CD | CodeDeploy Application、Deployment Groups、CodeDeploy artifacts S3 バケット |
| IAM（アプリ用） | ECS タスク実行 Role（`nestjs-hannibal-3-ecs-task-execution-role`）、関連ポリシー |
| セキュリティ分析 | Access Analyzer |

---

## 判断保留

現時点では消してよいか確定していないリソース。別 Issue で整理する。

| リソース | 状況 | 関連 Issue |
|---------|------|-----------|
| ECS Task Definition revisions | 直近10世代を保持・それ以前は deploy 時に自動 deregister。10の根拠: ECR ライフサイクルポリシーが直近10イメージを保持するため揃えている | #133 で方針決定・実装済み |
| GuardDuty detector | お試しで使用後コスト懸念（月 $3〜5）のため無効化済み。`terraform/foundation/guardduty.tf` にコメントアウトで保持。再有効化は不要 | #132 で確認済み |

---

## 関連ドキュメント

- [docs/setup/prerequisites.md](../setup/prerequisites.md) — 初回セットアップ時の手動作成手順
- [docs/operations/iam-management.md](./iam-management.md) — IAM 権限の分析・最小権限化
