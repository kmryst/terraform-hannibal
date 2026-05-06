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
| S3 バケット | `nestjs-hannibal-3-terraform-state` | Terraform state の保存先。削除すると state が失われ復旧困難 |
| S3 バケット | `nestjs-hannibal-3-cloudtrail-logs` | CloudTrail 監査ログの保存先 |
| S3 バケット | `nestjs-hannibal-3-athena-results` | Athena クエリ結果の出力先 |
| S3 バケット | `nestjs-hannibal-3-frontend` | フロントエンド静的ファイル。Terraform は data 参照のみでバケット本体は管理外 |
| DynamoDB テーブル | `terraform-state-lock` | Terraform 同時実行ロック。削除すると apply/destroy が排他制御できなくなる |
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
| IAM Role | `HannibalDeveloperRole-Dev` | 開発者手動操作用 Role |
| IAM Role | `HannibalPRPlanRole-Dev` | PR terraform plan 用 Role（read-only） |
| IAM Policy | `HannibalCICDPolicy-Dev` | CI/CD Role に attach 中のポリシー（実運用中） |
| IAM Policy | `HannibalCICDPolicy-Dev-Minimal` | 最小権限化検討用（未 attach） |
| IAM Policy | `HannibalPRPlanPolicy-Dev` | PR plan 用 read-only ポリシー |
| IAM Policy | `HannibalDeveloperPolicy-Dev` | 開発者 Role 用ポリシー |
| Athena Workgroup | `hannibal-cloudtrail-analysis` | CloudTrail 分析用。`prevent_destroy = true` 設定済み |
| Athena Database | `hannibal_cloudtrail_db` | CloudTrail 分析用論理 DB。`prevent_destroy = true` 設定済み |
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
| CloudTrail trail 本体 | 存在しない（foundation・dev 環境のいずれにも未定義）。ログ用 S3 バケット `nestjs-hannibal-3-cloudtrail-logs` は空で存在する。foundation Terraform に追加予定 | #132 で調査完了・別 Issue で実装 |
| Athena results S3 バケット | `nestjs-hannibal-3-athena-results` が存在しない。Athena workgroup / Glue DB は foundation に存在するがクエリ実行不可の状態。S3 バケット手動作成が必要 | #132 で調査完了・別 Issue で実装 |
| GuardDuty detector | お試しで使用後コスト懸念（月 $3〜5）のため無効化済み。`terraform/foundation/guardduty.tf` にコメントアウトで保持。再有効化は不要 | #132 で確認済み |

---

## 関連ドキュメント

- [docs/setup/prerequisites.md](../setup/prerequisites.md) — 初回セットアップ時の手動作成手順
- [docs/operations/iam-management.md](./iam-management.md) — IAM 権限の分析・最小権限化
