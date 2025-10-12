# 運用ガイド - NestJS Hannibal 3

## 📋 運用ドキュメント構成

このドキュメントでは **日常運用・監視・トラブルシュート** の実践手順を説明します。

**関連ドキュメント:**
- [iam-management.md](./iam-management.md) - IAM権限最適化（Athena分析）
- [monitoring.md](./monitoring.md) - CloudWatch監視・CloudTrail分析
- [docs/deployment/codedeploy-blue-green.md](../deployment/codedeploy-blue-green.md) - デプロイ詳細

---

## 🏗️ 運用原則（実装済み）

### 1. Infrastructure as Code
- **Terraform管理**: 全リソースをコード化（手動変更禁止）
- **State管理**: S3 + DynamoDB Lock で一貫性確保
- **環境分離**: `terraform/environments/dev/` で管理

### 2. 最小権限原則
- **IAM最適化**: 160権限 → 76権限 (47.5%削減達成)
- **Permission Boundary**: HannibalCICDBoundary で上限設定
- **AssumeRole**: 一時的な権限昇格のみ

### 3. 監査性・トレーサビリティ
- **CloudTrail**: 全API呼び出しを90日間保存
- **Athena分析**: 月次で権限使用状況レビュー
- **GitHub Actions Log**: デプロイ履歴の完全記録

---

## � 日常運用タスク

### サービス起動（月初など）

**GitHub Actions手動実行:**
```
Workflow: deploy.yml
Inputs:
  - deployment_mode: provisioning
  - environment: dev
```

**所要時間**: 約15分  
**結果**: ECS Fargate + RDS + ALB が起動、サービス開始

### サービス停止（月末など）

**Terraform destroy実行:**
```powershell
cd terraform\environments\dev
terraform destroy -target=module.compute
terraform destroy -target=module.storage

# 残すリソース: VPC, IAM, CloudTrail
```

**コスト削減**: $30-50/月 → $5/月 (94%削減)

### デプロイ実行（コード更新時）

**Blue/Green Deployment:**
```
Workflow: deploy.yml
Inputs:
  - deployment_mode: bluegreen
  - environment: dev
```

**所要時間**: 約5分  
**仕組み**: Green環境起動 → ALB切替 → Blue削除

**Canary Deployment:**
```
Workflow: deploy.yml
Inputs:
  - deployment_mode: canary
  - environment: dev
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
| DATABASE_URL未設定 | GitHub Secrets追加 → 再デプロイ |
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

**原因**: 前回の terraform apply が異常終了、または別操作実行中

**解決方法:**
```powershell
# Lock ID確認
aws dynamodb scan --table-name terraform-state-lock

# Lock強制解除（他の操作がないことを確認）
cd terraform\environments\dev
terraform force-unlock <LOCK_ID>
```

**予防策**: `terraform apply` を Ctrl+C で中断しない

### 4. RDS接続エラー

**症状**: `FATAL: password authentication failed`

**原因調査:**
```powershell
# Secrets Manager確認
aws secretsmanager get-secret-value `
  --secret-id hannibal/db/password

# Security Group確認
aws ec2 describe-security-groups `
  --group-ids <RDS_SG_ID>
```

**解決方法:**
1. DATABASE_URL が正しいか確認
2. RDS Security Group でECSからの通信を許可
3. パスワード変更時は Secrets Manager + GitHub Secrets を同時更新

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

**GitHub Dependabot設定済み:**
- 自動PR作成: 依存関係の脆弱性検出時
- 対応: PR内容確認 → マージ

**確認コマンド:**
```powershell
# 未対応PR一覧
gh pr list --label dependencies
```

### セキュリティスキャン結果確認

**GitHub Security タブ:**
- CodeQL / Trivy / tfsec / Gitleaks の結果を統合表示
- Critical/High の脆弱性は即座対応

---

## 📋 定期メンテナンス

| 頻度 | タスク | 所要時間 |
|------|--------|---------|
| **日次** | CloudWatch Alarm確認 | 5分 |
| **週次** | Dependabot PR マージ | 15分 |
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

**最終更新**: 2025年10月12日  
**運用レベル**: ポートフォリオ向けDevOps実装（本番運用可能）  
**サポート**: トラブル時は `docs/troubleshooting/README.md` 参照