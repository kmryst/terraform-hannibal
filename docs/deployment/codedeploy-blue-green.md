# CodeDeploy Blue/Green Deployment Guide

## 概要

このプロジェクトでは、AWS CodeDeployを使用したECS Blue/Green deploymentを実装しています。これにより、無停止でのアプリケーションデプロイメントが可能になります。

## アーキテクチャ

### コンポーネント
- **CodeDeploy Application**: `nestjs-hannibal-3-codedeploy-app`
- **Deployment Group**: `nestjs-hannibal-3-deployment-group`
- **Blue Target Group**: `nestjs-hannibal-3-blue-tg` (本番トラフィック)
- **Green Target Group**: `nestjs-hannibal-3-green-tg` (テストトラフィック)
- **Production Listener**: Port 80
- **Test Listener**: Port 8080

### デプロイメントフロー
1. 新しいタスク定義を登録
2. Green環境に新しいバージョンをデプロイ
3. Test Listener (8080) でテスト実行
4. ヘルスチェック通過後、Production Listener (80) にトラフィック切り替え
5. 5分後にBlue環境を自動終了

## 使用方法

### 1. 手動デプロイメント

```powershell
# PowerShellスクリプトを使用
.\scripts\deployment\deploy-codedeploy.ps1 -ImageTag "v1.2.3"
```

### 2. GitHub Actions

GitHub Actionsワークフローが自動的にCodeDeployを使用してデプロイメントを実行します：

```yaml
# .github/workflows/deploy.yml で自動実行
# コミットSHAをタグとして使用
```

### 3. AWS CLI直接実行

```bash
# 新しいタスク定義を登録
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition --cli-input-json file://task-def.json --query 'taskDefinition.taskDefinitionArn' --output text)

# CodeDeployデプロイメント実行
aws deploy create-deployment \
  --application-name nestjs-hannibal-3-codedeploy-app \
  --deployment-group-name nestjs-hannibal-3-deployment-group \
  --revision '{"revisionType":"AppSpecContent","appSpecContent":{"content":"..."}}'
```

## 監視とトラブルシューティング

### ステータス確認

```powershell
# CodeDeploy専用監視スクリプト
.\scripts\monitoring\codedeploy-status.ps1

# 従来のBlue/Green監視スクリプト
.\scripts\monitoring\blue-green-status.ps1
```

### 主要な監視項目

1. **CodeDeploy Deployment Status**
   - Succeeded / Failed / InProgress / Queued

2. **Target Group Health**
   - Blue/Green環境のヘルスチェック状況

3. **ALB Listener Rules**
   - トラフィック分散の重み設定

4. **ECS Service Status**
   - タスクの実行状況

### よくある問題と対処法

#### 1. デプロイメントが失敗する
```bash
# デプロイメント詳細を確認
aws deploy get-deployment --deployment-id <DEPLOYMENT_ID>

# ログを確認
aws logs describe-log-groups --log-group-name-prefix "/aws/codedeploy"
```

#### 2. ヘルスチェックが通らない
```bash
# Target Groupのヘルス状況を確認
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>

# アプリケーションログを確認
aws logs tail /ecs/nestjs-hannibal-3-api-task --follow
```

#### 3. トラフィック切り替えが発生しない
```bash
# Listener Rulesの重み設定を確認
aws elbv2 describe-rules --listener-arn <LISTENER_ARN>
```

## 設定

### Terraform設定

主要な設定は以下のファイルで管理されています：

- `terraform/backend/codedeploy.tf`: CodeDeploy関連リソース
- `terraform/backend/main.tf`: ECSサービス設定（deployment_controller: CODE_DEPLOY）

### 環境変数

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| PROJECT_NAME | プロジェクト名 | nestjs-hannibal-3 |
| AWS_REGION | AWSリージョン | ap-northeast-1 |
| BAKE_TIME | ベイクタイム（分） | 5 |

## セキュリティ

### IAM権限

CodeDeployサービスロールには以下の権限が付与されています：

- `AWSCodeDeployRoleForECS`: CodeDeploy基本権限
- `HannibalCICDBoundary`: Permission Boundary適用

### 通知設定

デプロイメント結果はSNSトピックに通知されます：

- 成功時: `nestjs-hannibal-3-deployment-notifications`
- 失敗時: 自動ロールバック実行

## パフォーマンス

### デプロイメント時間

- **準備フェーズ**: 1-2分
- **Green環境デプロイ**: 3-5分
- **ヘルスチェック**: 2-3分
- **トラフィック切り替え**: 1分
- **Blue環境終了**: 5分（設定可能）

**合計**: 約12-16分

### コスト最適化

- ベイクタイム: 5分（最小限に設定）
- 自動終了: 有効（リソース使用量削減）
- 失敗時自動ロールバック: 有効（手動介入不要）

## 参考リンク

- [AWS CodeDeploy User Guide](https://docs.aws.amazon.com/codedeploy/)
- [ECS Blue/Green Deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html)
- [Application Load Balancer Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)