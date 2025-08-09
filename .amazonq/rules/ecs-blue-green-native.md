# ECS Native Blue/Green Deployment Rules

## 概要
Amazon ECS blue/green deployments (Released July 17, 2025)
2025年7月17日にリリースされたECSネイティブのBlue/Green deployment機能に関する設定とルール

## 動作確認済み環境
- **Terraform**: 1.12.1 (2025年7月リリース最新版)
- **AWS Provider**: 6.7.0 (2025年7月31日リリース最新版)
- **実装プロジェクト**: nestjs-hannibal-3
- **確認日**: 2025年8月4日
- **動作状況**: ✅ 完全動作確認済み

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

## ⚠️ 重要な制約事項
- **`deployment_circuit_breaker`、`maximum_percent`、`minimum_healthy_percent`は`strategy = "BLUE_GREEN"`と併用不可**
- Blue/Green deploymentでは、これらの設定は自動的に最適化される
- 併用するとTerraform構文エラーが発生する
- **Terraform AWS Provider v6.4.0以降必須**

## 動作確認済み最小構成（推奨）

### ECSサービス設定（実装済み・動作確認済み）
```hcl
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_task_count
  launch_type     = "FARGATE"
  
  # ECS Native Blue/Green Deployment（最小構成）
  deployment_configuration {
    strategy = "BLUE_GREEN"
    bake_time_in_minutes = 5
  }
  
  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
  
  # Blue/Green用高度なロードバランサー設定
  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
    
    # Blue/Green専用設定
    advanced_configuration {
      alternate_target_group_arn = aws_lb_target_group.green.arn
      production_listener_rule   = aws_lb_listener_rule.production.arn
      test_listener_rule        = aws_lb_listener_rule.test.arn
      role_arn                  = aws_iam_role.ecs_service_role.arn
    }
  }
}

# Blue/Green用追加リソース
resource "aws_lb_target_group" "green" {
  name        = "${var.project_name}-green-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "ip"
  
  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 15
    matcher             = "200-399"
  }
}

resource "aws_lb_listener_rule" "production" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  
  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = 100
      }
    }
  }
  
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_listener_rule" "test" {
  listener_arn = aws_lb_listener.test.arn
  priority     = 100
  
  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = 100
      }
    }
  }
  
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
```

### 必要なIAM権限（Terraform公式対応）
```hcl
# ECSサービス用Blue/Green権限
resource "aws_iam_role" "ecs_service_role" {
  name = "${var.project_name}-ecs-service-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_blue_green_policy" {
  name = "${var.project_name}-ecs-blue-green-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_service_blue_green" {
  role       = aws_iam_role.ecs_service_role.name
  policy_arn = aws_iam_policy.ecs_blue_green_policy.arn
}

# ライフサイクルフック用IAMロール
resource "aws_iam_role" "ecs_lifecycle_hook" {
  name = "${var.project_name}-ecs-lifecycle-hook-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_lifecycle_hook_policy" {
  name = "${var.project_name}-ecs-lifecycle-hook-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.deployment_validation.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_lifecycle_hook" {
  role       = aws_iam_role.ecs_lifecycle_hook.name
  policy_arn = aws_iam_policy.ecs_lifecycle_hook_policy.arn
}
```

## GitHub Actions連携（オプション）

### AWS CLI経由でのBlue/Green deployment
```yaml
# Terraformで設定済みの場合、通常のECS更新で自動的にBlue/Green実行
- name: Update ECS Service (Auto Blue/Green)
  run: |
    aws ecs update-service \
      --cluster nestjs-hannibal-3-cluster \
      --service nestjs-hannibal-3-api-service \
      --task-definition $NEW_TASK_DEF
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

## 完全な設定例（オプション機能含む）

### ライフサイクルフック付きECSサービス設定
```hcl
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_task_count
  launch_type     = "FARGATE"
  
  # Blue/Green deployment設定（オプション機能含む）
  deployment_configuration {
    strategy = "BLUE_GREEN"
    bake_time_in_minutes = 5
    
    # ライフサイクルフック（オプション）
    lifecycle_hook {
      hook_target_arn = aws_lambda_function.deployment_validation.arn
      role_arn       = aws_iam_role.ecs_lifecycle_hook.arn
      lifecycle_stages = ["PRE_SCALE_UP", "POST_SCALE_UP", "TEST_TRAFFIC_SHIFT"]
    }
  }
  
  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
  
  # Blue/Green用高度なロードバランサー設定
  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
    
    # Blue/Green専用設定
    advanced_configuration {
      alternate_target_group_arn = aws_lb_target_group.green.arn
      production_listener_rule   = aws_lb_listener_rule.production.arn
      test_listener_rule        = aws_lb_listener_rule.test.arn
      role_arn                  = aws_iam_role.ecs_service_role.arn
    }
  }
}
```

## 実装で得た重要な知見

### 1. 実際に動作する設定（Hannibal 3プロジェクトで確認済み）
```hcl
# 最小動作構成
deployment_configuration {
  strategy = "BLUE_GREEN"
  bake_time_in_minutes = 5
}

load_balancer {
  target_group_arn = aws_lb_target_group.blue.arn
  container_name   = "${var.project_name}-container"
  container_port   = var.container_port
  
  advanced_configuration {
    alternate_target_group_arn = aws_lb_target_group.green.arn
    production_listener_rule   = aws_lb_listener_rule.production.arn
    test_listener_rule         = aws_lb_listener_rule.test.arn
    role_arn                   = aws_iam_role.ecs_service_role.arn
  }
}
```

### 2. IAM権限の完全版（実装済み・動作確認済み）
```hcl
resource "aws_iam_policy" "ecs_blue_green_policy" {
  name = "${var.project_name}-ecs-blue-green-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # ALB操作権限
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeLoadBalancers",
          # ECS操作権限
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### 3. AWS管理ポリシー未提供
- ECS Native Blue/Green deployment用のAWS管理ポリシーは**存在しない**
- 2025年7月17日の新機能のため、カスタムポリシー作成が必須
- 将来的にAWS管理ポリシーが提供される可能性あり

### 4. Terraform構文制約
- **併用不可設定**: `deployment_circuit_breaker`、`maximum_percent`、`minimum_healthy_percent`
- **理由**: Blue/Green deploymentでは自動最適化される
- **エラー例**: "deployment_circuit_breaker cannot be used with strategy BLUE_GREEN"

## Terraform実装手順（Hannibal 3）

### Step 1: 既存リソースの名前変更
```hcl
# 既存のターゲットグループをblueに変更
resource "aws_lb_target_group" "blue" {
  name = "${var.project_name}-blue-tg"  # 既存の"api"から変更
  # ... 既存設定
}
```

### Step 2: ECSサービス設定更新
```hcl
# deployment_configurationにstrategy追加
deployment_configuration {
  strategy = "BLUE_GREEN"  # 追加
  bake_time_in_minutes = 5  # 追加
  # ... 既存設定
}
```

### Step 3: セキュリティグループ更新
```hcl
# ALBセキュリティグループにポート8080追加
resource "aws_security_group" "alb_sg" {
  # 既存のポート80設定
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # 新規追加: テストリスナー用ポート8080
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Step 4: terraform plan/apply実行
```bash
cd terraform/backend
terraform plan -var="client_url_for_cors=https://hamilcar-hannibal.click" -var="environment=dev"
terraform apply
```

## Hannibal 3固有の実装ポイント

### 現在の設定からの変更点
- **ターゲットグループ**: `aws_lb_target_group.api` → `aws_lb_target_group.blue`
- **ECSサービス**: `deployment_configuration`に`strategy = "BLUE_GREEN"`追加
- **ALBリスナー**: テスト用ポート8080追加
- **セキュリティグループ**: ポート8080のingress rule追加

### 動作の仕組み
1. **通常時**: Blue環境（ポート80）で稼働
2. **デプロイ時**: Green環境（ポート8080）で新バージョン起動
3. **ヘルスチェック**: Green環境の健全性確認
4. **トラフィック切り替え**: Blue → Green に一括切り替え
5. **完了**: 旧Blue環境を自動削除

### desired_count = 1での動作
- **デプロイ中**: 一時的に2個のタスク（Blue + Green）
- **完了後**: 1個のタスク（新Green環境）に戻る

## ベストプラクティス
- **本番環境**: Blue/Green deployment使用
- **開発環境**: Rolling Updateでコスト削減
- **ヘルスチェック**: 適切なタイムアウト値設定
- **監査ログ**: CloudTrailでデプロイ履歴追跡

## トラブルシューティング

### Terraform関連
- **構文エラー**: `deployment_circuit_breaker`は`deployment_configuration`内で使用不可
- **権限不足**: ECS操作権限（DescribeServices、UpdateService等）が必要
- **Provider版本**: v6.4.0未満では`strategy = "BLUE_GREEN"`未対応

### デプロイ関連
- **デプロイ停止**: ヘルスチェック設定とタイムアウト確認
- **ロールバック未実行**: CloudWatchアラームとロールバックポリシー確認
- **Lambda検証失敗**: 関数ログとIAM権限確認

### 権限関連
- **ALB操作失敗**: `elasticloadbalancing:ModifyListener`等の権限確認
- **ターゲット登録失敗**: `RegisterTargets`、`DeregisterTargets`権限確認
- **ECS操作失敗**: `ecs:DescribeServices`、`ecs:UpdateService`権限確認

---
**企業レベルのBlue/Green deployment実装完了**
**実装知見: Terraform v6.4.0 + カスタムIAMポリシー必須**