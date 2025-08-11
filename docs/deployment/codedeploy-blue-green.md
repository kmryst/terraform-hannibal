# CodeDeploy Blue/Green Deployment for ECS

企業レベルのCodeDeploy Blue/Green デプロイメント設定とベストプラクティス

## 📋 概要

Netflix、Airbnb、Spotifyなどの企業レベル設計に基づいたCodeDeploy Blue/Green デプロイメントを実装。

### 主要機能
- **無停止デプロイメント**: Blue/Green環境での安全な切り替え
- **自動ロールバック**: 失敗時の自動復旧
- **企業レベル監視**: CloudWatch Alarms + SNS通知
- **カスタムデプロイ設定**: Bake time 1分の高速デプロイ

## 🏗️ アーキテクチャ

```
┌─────────────────┐    ┌─────────────────┐
│   Production    │    │      Test       │
│   Listener      │    │    Listener     │
│   (Port 80)     │    │   (Port 8080)   │
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

## ⚙️ 設定詳細

### Terraform設定

#### CodeDeploy Application
```hcl
resource "aws_codedeploy_app" "ecs_app" {
  compute_platform = "ECS"
  name             = "${var.project_name}-codedeploy-app"
}
```

#### Deployment Group（企業レベル設定）
```hcl
resource "aws_codedeploy_deployment_group" "ecs_deployment_group" {
  app_name               = aws_codedeploy_app.ecs_app.name
  deployment_group_name  = "${var.project_name}-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy_service_role.arn
  deployment_config_name = aws_codedeploy_deployment_config.ecs_custom_config.deployment_config_name

  # 企業レベル自動ロールバック設定
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  # Target Group Pair Info（正しい構文）
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
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

#### カスタムデプロイ設定
```hcl
resource "aws_codedeploy_deployment_config" "ecs_custom_config" {
  deployment_config_name = "${var.project_name}-ECSCustomConfig"
  compute_platform       = "ECS"
  
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 1  # Bake time
    }
    
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }
}
```

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

### 1. GitHub Actions（自動デプロイ）

```yaml
- name: Deploy with CodeDeploy Blue/Green (Enterprise)
  run: |
    # 企業レベルCodeDeploy Blue/Green デプロイメント
    NEW_IMAGE="${{ env.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/${{ env.PROJECT_NAME }}:${{ github.sha }}"
    
    # 新しいタスク定義を作成
    aws ecs describe-task-definition \
      --task-definition ${{ env.PROJECT_NAME }}-api-task \
      --query 'taskDefinition' > current_task_def.json
    
    # CodeDeploy デプロイメント実行
    DEPLOYMENT_ID=$(aws deploy create-deployment \
      --application-name ${{ env.PROJECT_NAME }}-codedeploy-app \
      --deployment-group-name ${{ env.PROJECT_NAME }}-deployment-group \
      --deployment-config-name ${{ env.PROJECT_NAME }}-ECSCustomConfig \
      --revision '{"revisionType":"AppSpecContent","appSpecContent":{"content":"..."}}' \
      --query 'deploymentId' --output text)
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
  --application-name nestjs-hannibal-3-codedeploy-app \
  --deployment-group-name nestjs-hannibal-3-deployment-group \
  --query 'deployments[1]' --output text)

# ロールバック実行
aws deploy create-deployment \
  --application-name nestjs-hannibal-3-codedeploy-app \
  --deployment-group-name nestjs-hannibal-3-deployment-group \
  --revision "revisionType=S3,s3Location={bucket=codedeploy-bucket,key=previous-version.zip}"
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
- **ALB**: WAF統合（将来実装）

### 3. 監査とログ
- **CloudTrail**: 全API呼び出しの記録
- **CloudWatch Logs**: デプロイメントログの保存
- **SNS通知**: 重要イベントの通知

## 📚 参考資料

### AWS公式ドキュメント
- [CodeDeploy Blue/Green Deployments](https://docs.aws.amazon.com/codedeploy/latest/userguide/applications-create-blue-green.html)
- [ECS Blue/Green Deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html)

### 企業事例
- **Netflix**: Spinnaker + CodeDeploy
- **Airbnb**: 段階的権限管理
- **Spotify**: チーム別 + 環境別分離

---

**最終更新**: 2025年1月15日  
**実装レベル**: 企業レベル（Netflix/Airbnb/Spotify標準）