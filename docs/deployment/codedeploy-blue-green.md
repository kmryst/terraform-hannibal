# CodeDeploy デプロイメント for ECS

nestjs-hannibal-3プロジェクトのCodeDeployデプロイメント実装

## 📋 概要

AWS CodeDeployを使用したECSサービスのデプロイメント。3つのモードに対応。

### デプロイモード
- **Canary**: 10%→100%段階的切替
- **Blue/Green**: 即座切替
- **Provisioning**: 初期構築

### 主要機能
- **無停止デプロイメント**: Blue/Green環境での安全な切り替え
- **自動ロールバック**: 失敗時の自動復旧
- **GitHub Actions統合**: 自動化されたCI/CDパイプライン
- **高速デプロイ**: 1分のWait Timeで迅速切り替え

## 🏗️ アーキテクチャ

```
┌─────────────────┐    ┌─────────────────┐
│   Production    │    │      Test       │
│   Listener      │    │    Listener     │
│ (Port 443 HTTPS)│    │(Port 8080 HTTPS)│
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          ▼                      ▼
┌─────────────────┐    ┌─────────────────┐
│   Blue Target   │    │  Green Target   │
│     Group       │    │     Group       │
│   (Production)  │    │    (Staging)    │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          ▼                      ▼
┌─────────────────┐    ┌─────────────────┐
│   ECS Tasks     │    │   ECS Tasks     │
│   (Current)     │    │    (New)        │
└─────────────────┘    └─────────────────┘
```

Production traffic は ALB の 443 HTTPS listener で受け、80 HTTP listener は HTTPS redirect 専用にします。
Test listener の 8080 も HTTPS で TLS 終端します。
ALB から ECS task への通信は、private subnet と security group で制限された内部経路のため HTTP のまま維持します。

## ⚙️ 設定詳細

### Terraform設定

#### CodeDeploy Application
```hcl
resource "aws_codedeploy_app" "ecs_app" {
  compute_platform = "ECS"
  name             = "${var.project_name}-app"
}
```

#### Deployment Group
```hcl
resource "aws_codedeploy_deployment_group" "ecs_deployment_group" {
  app_name               = aws_codedeploy_app.ecs_app.name
  deployment_group_name  = "${var.project_name}-dg"
  service_role_arn       = aws_iam_role.codedeploy_service_role.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  # 自動ロールバック設定
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  # Target Group Pair Info（正しい構文）
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.https.arn]
      }
      test_traffic_route {
        listener_arns = [aws_lb_listener.test.arn]
      }
      target_group {
        name = aws_lb_target_group.blue.name
      }
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  # CloudWatch監視
  alarm_configuration {
    enabled = true
    alarms  = [aws_cloudwatch_metric_alarm.ecs_service_health.name]
  }
}
```

#### デプロイ設定
- **Canary**: `CodeDeployDefault.ECSCanary10Percent5Minutes`
- **Blue/Green**: `CodeDeployDefault.ECSAllAtOnce`
- **Bake Time**: 1分
- **Termination Wait**: 5分

### IAM権限（最小権限原則）

#### CodeDeploy Service Role
```hcl
resource "aws_iam_role_policy" "codedeploy_enhanced_policy" {
  name = "${var.project_name}-codedeploy-enhanced-policy"
  role = aws_iam_role.codedeploy_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:CreateTaskSet",
          "ecs:UpdateServicePrimaryTaskSet",
          "ecs:DeleteTaskSet",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:ModifyRule",
          "cloudwatch:DescribeAlarms",
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## 🚀 デプロイメント手順

### 1. GitHub Actions（手動デプロイ）

`deploy.yml` は `workflow_dispatch` で `main` から手動実行する。backend/frontend の build・test は PR gate（`pr-check.yml`）に一本化し、deploy workflow では再実行しない。

#### Canaryデプロイ
```yaml
- name: Deploy with CodeDeploy Canary
  if: ${{ inputs.deployment_mode == 'canary' }}
  run: |
    S3_BUCKET="${{ env.PROJECT_NAME }}-codedeploy-artifacts"
    S3_KEY="appspec-${{ github.sha }}.yaml"
    aws s3 cp appspec.yaml "s3://$S3_BUCKET/$S3_KEY"
    DEPLOYMENT_ID=$(aws deploy create-deployment \
      --application-name "${{ env.PROJECT_NAME }}-app" \
      --deployment-group-name "${{ env.PROJECT_NAME }}-dg" \
      --s3-location bucket="$S3_BUCKET",key="$S3_KEY",bundleType="YAML" \
      --query 'deploymentId' --output text)
    echo "🔍 CodeDeploy Canary deployment started: $DEPLOYMENT_ID"
    aws deploy wait deployment-successful --deployment-id "$DEPLOYMENT_ID"
```

#### Blue/Greenデプロイ
```yaml
- name: Deploy with CodeDeploy Blue/Green
  if: ${{ inputs.deployment_mode == 'bluegreen' }}
  run: |
    S3_BUCKET="${{ env.PROJECT_NAME }}-codedeploy-artifacts"
    S3_KEY="appspec-${{ github.sha }}.yaml"
    aws s3 cp appspec.yaml "s3://$S3_BUCKET/$S3_KEY"
    DEPLOYMENT_ID=$(aws deploy create-deployment \
      --application-name "${{ env.PROJECT_NAME }}-app" \
      --deployment-group-name "${{ env.PROJECT_NAME }}-dg" \
      --s3-location bucket="$S3_BUCKET",key="$S3_KEY",bundleType="YAML" \
      --query 'deploymentId' --output text)
    echo "🚀 CodeDeploy Blue/Green deployment started: $DEPLOYMENT_ID"
    aws deploy wait deployment-successful --deployment-id "$DEPLOYMENT_ID"
```

### 2. PowerShellスクリプト（手動デプロイ）

```powershell
# 基本デプロイ
.\scripts\deployment\deploy-codedeploy.ps1 -ImageTag "v1.2.3"

# 環境指定デプロイ
.\scripts\deployment\deploy-codedeploy.ps1 -ImageTag "v1.2.3" -Environment "staging"

# カスタム設定デプロイ
.\scripts\deployment\deploy-codedeploy.ps1 -ImageTag "v1.2.3" -DeploymentConfig "CustomConfig" -TimeoutMinutes 45
```

## 📊 監視とトラブルシューティング

### 1. ステータス監視

```powershell
# 基本ステータス確認
.\scripts\monitoring\blue-green-status.ps1

# 詳細情報表示
.\scripts\monitoring\blue-green-status.ps1 -Detailed
```

### 2. CloudWatch監視

#### メトリクス
- **HealthyHostCount**: ターゲットグループのヘルシーホスト数
- **UnHealthyHostCount**: アンヘルシーホスト数
- **TargetResponseTime**: レスポンス時間

#### アラーム設定
```hcl
resource "aws_cloudwatch_metric_alarm" "ecs_service_health" {
  alarm_name          = "${var.project_name}-ecs-service-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_actions       = [aws_sns_topic.deployment_notifications.arn]
}
```

### 3. ログ確認

```bash
# CodeDeployログ
aws logs get-log-events \
  --log-group-name "/aws/codedeploy/nestjs-hannibal-3" \
  --log-stream-name "latest-stream"

# ECSタスクログ
aws logs get-log-events \
  --log-group-name "/ecs/nestjs-hannibal-3-api-task" \
  --log-stream-name "ecs/nestjs-hannibal-3-container/task-id"
```

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 1. Target Group Pair Info エラー
```
Error: load_balancer_info.target_group_info is deprecated
```

**解決方法**: `target_group_pair_info`を使用
```hcl
load_balancer_info {
  target_group_pair_info {
    # 正しい構文
  }
}
```

#### 2. デプロイメントタイムアウト
```
Deployment timeout after 30 minutes
```

**解決方法**: 
- Bake timeを短縮（1分）
- ヘルスチェック設定を最適化
- タスク起動時間を短縮

#### 3. ロールバック失敗
```
Auto rollback failed
```

**解決方法**:
- CloudWatch Alarmの設定確認
- IAM権限の確認
- 手動ロールバック実行

### 手動ロールバック

```bash
# 前のデプロイメントIDを取得
PREV_DEPLOYMENT=$(aws deploy list-deployments \
  --application-name nestjs-hannibal-3-app \
  --deployment-group-name nestjs-hannibal-3-dg \
  --query 'deployments[1]' --output text)

# ロールバック実行
aws deploy create-deployment \
  --application-name nestjs-hannibal-3-app \
  --deployment-group-name nestjs-hannibal-3-dg \
  --revision "revisionType=S3,s3Location={bucket=nestjs-hannibal-3-codedeploy-artifacts,key=previous-version.yaml}"
```

## 📈 パフォーマンス最適化

### デプロイ時間短縮
1. **Bake Time**: 1分に設定
2. **ヘルスチェック**: 間隔30秒、タイムアウト5秒
3. **並列デプロイ**: 複数AZでの同時実行

### リソース最適化
1. **タスク定義**: 必要最小限のリソース
2. **イメージサイズ**: Multi-stage buildでの最適化
3. **起動時間**: アプリケーション起動の高速化

## 🔒 セキュリティベストプラクティス

### 1. IAM権限
- **最小権限原則**: 必要最小限の権限のみ付与
- **Permission Boundary**: 最大権限の制限
- **AssumeRole**: 環境別権限分離

### 2. ネットワークセキュリティ
- **セキュリティグループ**: 最小限のポート開放
- **VPC**: プライベートサブネットでのECS実行
- **ALB Listener**: 外部公開面は HTTPS。80 は redirect 専用、8080 test listener も HTTPS
- **ALB → ECS**: private subnet と security group で制限された内部通信として HTTP を維持
- **ALB**: WAF統合（将来実装）

### 3. 監査とログ
- **CloudTrail**: 全API呼び出しの記録
- **CloudWatch Logs**: デプロイメントログの保存
- **SNS通知**: 重要イベントの通知

## 📚 参考資料

### AWS公式ドキュメント
- [CodeDeploy Blue/Green Deployments](https://docs.aws.amazon.com/codedeploy/latest/userguide/applications-create-blue-green.html)
- [ECS Blue/Green Deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html)

---

**最終更新**: 2026年5月21日
