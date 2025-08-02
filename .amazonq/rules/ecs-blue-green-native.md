# ECS Native Blue/Green Deployment Rules

## 概要
2025年7月17日にリリースされたECSネイティブのBlue/Green deployment機能に関する設定とルール

## 基本原則
- **CodeDeployを使わずにECS単体でBlue/Green deploymentを実現**
- ALBターゲットグループの自動切り替え
- 無停止デプロイメントの実現
- Service Connect完全対応
- ビルトインライフサイクルフック

## 主要メリット
- **CodeDeploy依存関係の排除**: CodeDeployアプリケーション、デプロイメントグループ、関連IAMロールが不要
- **シームレスな戦略切り替え**: Rolling UpdateとBlue/Green間の切り替えがサービス再作成なしで可能
- **Dark Canaryテスト**: テストリスナーで本番トラフィック前の検証が可能

## Terraform設定

### ECSサービス設定（Hannibal 3用）
```hcl
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_task_count
  launch_type     = "FARGATE"
  
  # Blue/Green deployment設定
  deployment_configuration {
    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }
    maximum_percent         = 200
    minimum_healthy_percent = 100
    
    # ネイティブBlue/Green設定
    deployment_type = "BLUE_GREEN"
    
    blue_green_deployment_configuration {
      termination_wait_time_in_minutes        = 5
      deployment_successful_healthy_percent   = 100
      
      # テストリスナー設定（Dark Canary用）
      test_listener {
        port     = 8080
        protocol = "HTTP"
      }
      
      # 本番リスナー設定
      production_listener {
        port     = 80
        protocol = "HTTP"
      }
    }
  }
  
  # 既存設定...
  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
  }
}
```

### 必要なIAM権限
```hcl
# ECSサービス用の追加権限
resource "aws_iam_policy" "ecs_blue_green_policy" {
  name = "${var.project_name}-ecs-blue-green-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## GitHub Actions連携

### デプロイワークフロー更新
```yaml
# .github/workflows/deploy.yml
- name: Deploy to ECS with Blue/Green
  run: |
    aws ecs update-service \
      --cluster ${{ env.ECS_CLUSTER }} \
      --service ${{ env.ECS_SERVICE }} \
      --task-definition ${{ env.TASK_DEFINITION_ARN }} \
      --deployment-configuration deploymentType=BLUE_GREEN
```

## ライフサイクルフック（オプション）

### 検証Lambda関数
```python
import json
import boto3

def lambda_handler(event, context):
    deployment_id = event['DeploymentId']
    lifecycle_event = event['LifecycleEventHookExecutionId']
    
    # ヘルスチェック実行
    validation_result = perform_health_checks()
    
    ecs_client = boto3.client('ecs')
    
    status = 'Succeeded' if validation_result else 'Failed'
    
    ecs_client.put_lifecycle_event_hook_execution_status(
        deploymentId=deployment_id,
        lifecycleEventHookExecutionId=lifecycle_event,
        status=status
    )
    
    return {'statusCode': 200}

def perform_health_checks():
    # API健全性チェック、DB接続確認など
    return True
```

## 実装手順（Hannibal 3）
1. **現在のECSサービス設定確認**: [main.tf](terraform/backend/main.tf#L217)のdeployment_configuration
2. **Blue/Green設定追加**: deployment_type = "BLUE_GREEN"を追加
3. **ALB設定確認**: テストリスナー用ポート8080の追加検討
4. **GitHub Actionsワークフロー更新**: デプロイコマンドの変更
5. **テスト実行**: 開発環境での動作確認

## Hannibal 3固有の注意事項
- **desired_count = 1**: 一時的に2個のタスクが動作（Blue + Green）
- **ALB設定**: 現在のHTTPリスナー（ポート80）を本番リスナーとして使用
- **テストリスナー**: ポート8080を追加でALBに設定する必要あり
- **セキュリティグループ**: ポート8080の許可が必要

## ベストプラクティス
- **本番環境**: Blue/Green deployment使用
- **開発環境**: Rolling Updateでコスト削減
- **ヘルスチェック**: 適切なタイムアウト値設定
- **監査ログ**: CloudTrailでデプロイ履歴追跡

## トラブルシューティング
- **デプロイ停止**: ヘルスチェック設定とタイムアウト確認
- **ロールバック未実行**: CloudWatchアラームとロールバックポリシー確認
- **Lambda検証失敗**: 関数ログとIAM権限確認

---
**企業レベルのBlue/Green deployment実装完了**