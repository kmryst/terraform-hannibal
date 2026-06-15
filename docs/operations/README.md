# 運用ガイド

## 📋 運用ドキュメント構成

このドキュメントでは **日常運用・監視・トラブルシュート** の実践手順を説明します。

**関連ドキュメント:**
- [iam-management.md](./iam-management.md) - IAM権限最適化（Athena分析）
- [monitoring.md](./monitoring.md) - CloudWatch監視・CloudTrail分析
- [slo.md](./slo.md) - SLO（レスポンスタイム・エラー率・稼働率）
- [runbook.md](./runbook.md) - CloudWatch Alarm / ECS / デプロイ失敗時の対応手順
- [terraform-runbook.md](./terraform-runbook.md) - Terraform init / plan / apply / state lock / import / drift 確認
- [rollback-plan.md](./rollback-plan.md) - Terraform apply 失敗・誤変更・state 復元の rollback 手順
- [quality-gates.md](./quality-gates.md) - PR品質ゲート（Terraform lint / IaC security / secret scan）
- [action-pin-review.md](./action-pin-review.md) - GitHub Actions action pin の Tier分類・SHA検証・advisory確認とTier Bレビュー手順
- [dependency-management.md](./dependency-management.md) - npm依存更新、lockfile、audit、既知peer warningの運用方針
- [pr-terraform-plan-role-design.md](./pr-terraform-plan-role-design.md) - PR terraform plan用AWS Role/OIDC権限設計補足
- [docs/deployment/codedeploy-blue-green.md](../deployment/codedeploy-blue-green.md) - デプロイ詳細

---

## 🏗️ 運用原則（実装済み）

### 1. Infrastructure as Code
- **Terraform管理**: 全リソースをコード化（手動変更禁止）
- **State管理**: S3 backend + S3 lockfile で一貫性確保（DynamoDB Lock は移行期間中のみ併用）
- **環境分離**: `terraform/environments/dev/` で管理

### 2. 最小権限原則
- **IAM設計**: role 分離・write/exec action 列挙・read 系プレフィックス wildcard・Permission Boundary による最小権限設計（#164, #293）
- **Permission Boundary**: 全 Hannibal 系 Role に専用 Boundary を付与し最大権限を制限
- **AssumeRole**: 一時的な権限昇格のみ

### 3. 監査性・トレーサビリティ
- **CloudTrail**: 全API呼び出しを90日間保存
- **Athena分析**: 月次で権限使用状況レビュー
- **GitHub Actions Log**: デプロイ履歴の完全記録

### 4. PR gate と deploy workflow の分離
- **品質保証**: backend/frontend の build・test は PR gate（`pr-check.yml`）で確認する
- **デプロイ**: `deploy.yml` は PR gate 通過済みの `main` を手動実行する前提で、test job は持たない
- **責務分離**: deploy workflow は Terraform apply、frontend build、S3 sync、ECR push、CodeDeploy に集中する

---

## 日常運用タスク

### サービス起動（月初など）

**GitHub Actions手動実行:**
```
Workflow: deploy.yml
Inputs:
  - deployment_mode: provisioning
```

**所要時間**: 約15分  
**結果**: ECS Fargate + RDS + ALB が起動、サービス開始

### サービス停止（月末など）

**GitHub Actions手動実行:**
```
Workflow: destroy.yml
Inputs:
  - confirm: DESTROY
```

`destroy.yml` は CodeDeploy 停止、ECS scale down、Terraform destroy、S3/ECR/ELB の best-effort cleanup を順に実行します。
永続リソースと一時リソースの境界は [aws-resources.md](./aws-resources.md) を参照してください。

**コスト削減**: $30-50/月 → $5/月 (94%削減)

### デプロイ実行（コード更新時）

**Blue/Green Deployment:**
```
Workflow: deploy.yml
Inputs:
  - deployment_mode: bluegreen
```

**所要時間**: 約5分  
**仕組み**: Green環境起動 → ALB切替 → Blue削除

**Canary Deployment:**
```
Workflow: deploy.yml
Inputs:
  - deployment_mode: canary
```

**所要時間**: 約7分  
**仕組み**: 10%トラフィック → 検証 → 100%切替

---

## 📊 監視・ヘルスチェック

### CloudWatch Dashboards

**URL**: AWS Console → CloudWatch → Dashboards → `nestjs-hannibal-3`

**監視項目:**
| メトリクス | 閾値 | アラート条件 |
|----------|------|------------|
| **ECS CPU** | 80% | 5分間継続 |
| **ECS Memory** | 90% | 5分間継続 |
| **ALB 5xx Error** | 10回/5分 | 即座通知 |
| **RDS Connections** | 80 (上限100) | 5分間継続 |
| **ALB Target Health** | Unhealthy | 2回連続 |

### ログ確認

**ECS Task Logs:**
```powershell
aws logs tail /ecs/nestjs-hannibal-3 --follow
```

**ALB Access Logs:**
```powershell
# S3保存先確認
aws s3 ls s3://nestjs-hannibal-3-alb-logs/ --recursive
```

**CloudTrail Logs (Athena分析):**
```sql
-- 直近24時間の権限使用状況
SELECT 
  eventName,
  COUNT(*) as count,
  userIdentity.principalId
FROM cloudtrail_logs 
WHERE eventTime >= date_add('hour', -24, current_timestamp)
GROUP BY eventName, userIdentity.principalId
ORDER BY count DESC
LIMIT 20;
```

### コスト監視

**Billing Alarm設定済み:**
- **閾値**: $50/月
- **通知**: SNS → Email
- **確認方法**: AWS Console → Billing → Budgets

---

## 🔧 トラブルシューティング

### 1. ECS Task起動失敗

**症状**: Task が Pending → Stopped を繰り返す

**原因調査:**
```powershell
# Task停止理由確認
aws ecs describe-tasks `
  --cluster nestjs-hannibal-3-cluster `
  --tasks <TASK_ARN> `
  --query 'tasks[0].stoppedReason'

# CloudWatch Logs確認
aws logs tail /ecs/nestjs-hannibal-3 --follow
```

**よくある原因と解決方法:**
| 原因 | 解決方法 |
|------|---------|
| RDS managed secret参照不可 | IAM（ECS実行ロール）にSecrets Manager参照権限付与 → 再デプロイ |
| ECRイメージ取得失敗 | NAT Gateway確認 |
| メモリ不足 | Task Definition のメモリ増加 |

### 2. CodeDeploy Blue/Green失敗

**症状**: Deployment Status が Failed

**原因調査:**
```powershell
# デプロイ履歴確認
aws deploy list-deployments `
  --application-name nestjs-hannibal-3-app

# 失敗詳細確認
aws deploy get-deployment `
  --deployment-id <DEPLOYMENT_ID>
```

**ロールバック手順:**
```powershell
# 自動ロールバック（推奨）
aws deploy stop-deployment `
  --deployment-id <DEPLOYMENT_ID> `
  --auto-rollback-enabled

# 手動: 前バージョンへ再デプロイ
git revert HEAD
git push origin main
```

### 3. Terraform State Lock

**症状**: `Error: Error acquiring the state lock`

Terraform state lock は S3 lockfile を正とし、DynamoDB lock table は #189 まで移行期間用として併用します。
force-unlock、S3 lockfile 実動作確認、drift 確認は [Terraform Runbook](./terraform-runbook.md) を参照してください。
apply 失敗や state 復元が必要な場合は [Terraform Rollback Plan](./rollback-plan.md) を参照してください。

### 4. RDS接続エラー

**症状**: `FATAL: password authentication failed`

**原因調査:**
```powershell
# Secrets Manager確認
aws secretsmanager get-secret-value `
  --secret-id <RDS_MANAGED_SECRET_ARN_or_NAME>

# Security Group確認
aws ec2 describe-security-groups `
  --group-ids <RDS_SG_ID>
```

**解決方法:**
1. Secrets Manager の値（DB_HOST/DB_USER/DB_PASSWORD/DB_NAME など）が正しいか確認
2. RDS Security Group でECSからの通信を許可
3. パスワード変更時は Secrets Manager を更新（アプリ側はECS再起動で反映）

### 5. CloudFront キャッシュ問題

**症状**: Frontend更新が反映されない

**解決方法:**
```powershell
# キャッシュ無効化
aws cloudfront create-invalidation `
  --distribution-id <DISTRIBUTION_ID> `
  --paths "/*"
```

**所要時間**: 約5分

---

## 🛡️ セキュリティ運用

### IAM権限レビュー（月次）

**Athena分析クエリ:**
```sql
-- 過去30日間の権限使用状況
SELECT 
  eventName,
  COUNT(*) as usage_count
FROM cloudtrail_logs 
WHERE eventTime >= date_add('day', -30, current_date)
  AND userIdentity.sessionContext.sessionIssuer.userName = 'HannibalCICDRole-Dev'
GROUP BY eventName
ORDER BY usage_count DESC;
```

**見直し基準:**
- 使用回数 0 の権限 → 削除検討
- 高頻度の権限 → 最適化検討

### Dependabot PR対応（週次）

Dependabot / dependency graph 周辺の用語整理と action pin の現行運用は [quality-gates.md](./quality-gates.md) と [action-pin-review.md](./action-pin-review.md) を参照します。
[dependency-management.md](./dependency-management.md) は root / client のnpm依存、段階的lockfile更新、audit scope、既知peer warningの正本です。
[ADR 0017](../adr/0017-pin-github-actions-by-owner-tier.md) は、GitHub Actions action pin の Tier A / Tier B 方針とトレードオフを記録する背景文書です。

**GitHub Dependabot 設定済み:**
- Dependency graph / Dependabot alerts / Dependabot security updates は有効化済み（2026-06-10）
- GitHub Actions の Dependabot version updates は `.github/dependabot.yml` で週次実行
- npm ecosystem の version updates は #365 で追加対応する

**対応方針:**
- Dependabot security update PR は、対応する alert、修正 version、CI 結果を確認してマージする
- Dependabot version update PR は、release notes / changelog、breaking change、CI 結果を確認してマージする
- GitHub Actions の Tier B action（`@<sha> # vX.Y.Z`）を更新する PR では、`@<sha>` と `# vX.Y.Z` の tag commit が一致すること、workflow permissions / secrets / OIDC / artifact 入出力への影響を確認する
- Tier B SHA pin の Dependabot 追従更新は #366 で次回 PR を観測する

**確認コマンド:**
```powershell
# 未対応PR一覧
gh pr list --label dependencies

# GitHub Actions 更新PR一覧
gh pr list --label github_actions
```

### セキュリティスキャン結果確認

**GitHub Security タブ:**
- CodeQL / Trivy 依存関係・コンテナスキャンの結果を統合表示
- `security-scan.yml` は毎週月曜 00:15 UTC（09:15 JST）と手動実行で確認
- Critical/High の脆弱性は即座対応

**PR品質ゲート:**
- `TFLint` / `Trivy Config Scan` / `Gitleaks Secret Scan` は PR Check で確認
- `Trivy Config Scan` は初期導入時点では review signal として扱い、required status check 化は後続 Issue で判断
- 詳細は [quality-gates.md](./quality-gates.md) を参照

---

## 📋 定期メンテナンス

| 頻度 | タスク | 所要時間 |
|------|--------|---------|
| **日次** | CloudWatch Alarm確認 | 5分 |
| **週次** | Dependabot PR レビュー / マージ | 15分 |
| **週次** | Security Scan 結果確認 | 10分 |
| **月次** | IAM権限レビュー (Athena) | 30分 |
| **月次** | コスト分析 (Cost Explorer) | 15分 |
| **四半期** | CloudTrail ログ分析 | 1時間 |

---

## 📚 関連リソース

- **AWS Console Shortcuts:**
  - [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#logsV2:log-groups)
  - [ECS Cluster](https://console.aws.amazon.com/ecs/home?region=ap-northeast-1#/clusters)
  - [CodeDeploy Deployments](https://console.aws.amazon.com/codesuite/codedeploy/deployments?region=ap-northeast-1)
  - [RDS Instances](https://console.aws.amazon.com/rds/home?region=ap-northeast-1#databases:)

- **CLI Aliases推奨:**
```powershell
# PowerShell Profile に追加
function Watch-ECSLogs {
  aws logs tail /ecs/nestjs-hannibal-3 --follow
}

function Get-Deployments {
  aws deploy list-deployments --application-name nestjs-hannibal-3-app
}
```

---

**最終更新**: 2026年06月15日
**運用レベル**: ポートフォリオ向けDevOps実装（本番運用可能）  
**サポート**: トラブル時は `docs/troubleshooting/README.md` 参照
