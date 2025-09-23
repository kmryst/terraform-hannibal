# --- AWS Professional Environment Configuration ---
locals {
  # 環境別リソース最適化（Netflix/Airbnb/Spotify標準パターン）
  enable_multi_az        = var.environment != "dev"
  enable_backup          = var.environment != "dev"
  backup_retention_days  = var.environment == "prod" ? 7 : 0
  publicly_accessible    = var.environment == "dev"
  deletion_protection    = var.environment == "prod"
}

# ⭐️ --- ECR Repository (手動作成済み) --- ⭐️
# ⭐️ 手動で作成済みのECRリポジトリを使用 ⭐️
# 理由: 権限エラー回避、CI/CD安定性向上、実行時間短縮
# ECR URI: variables.tfで定義済み

# ⭐️ --- ECR Lifecycle Policy (Terraform管理) --- ⭐️
# ⭐️ 古いイメージを自動削除するためのライフサイクルポリシー ⭐️
# Infrastructure as Code原則に従いTerraformで管理
resource "aws_ecr_lifecycle_policy" "nestjs_hannibal_3_policy" {
  repository = "nestjs-hannibal-3" # 直接リポジトリ名を指定

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# --- ECS Cluster ---
# ECSクラスタを作成（Fargateタスクを実行するための論理的なグループ）
# クラスタは、タスクやサービスを論理的にグループ化するためのコンテナです
resource "aws_ecs_cluster" "main" {    # main は Terraformリソースのローカル名
  name = "${var.project_name}-cluster" # AWS上で作成される実際のクラスタの名前
}

# --- ECS Task Definition ---
# ECSタスクの定義（コンテナの設定、CPU、メモリ、環境変数など）
# タスク定義は、コンテナの実行に必要な設定を定義します
# タスク（Task）は、そのタスク定義をもとに実際に起動された「インスタンス」です
resource "aws_ecs_task_definition" "api" {                            # APIサーバ用のコンテナなので
  family                   = "${var.project_name}-api-task"           # タスク定義のファミリー名
  requires_compatibilities = ["FARGATE"]                              # Fargateで実行することを指定（サーバーレスコンピューティング）
  network_mode             = "awsvpc"                                 # Fargateではawsvpcモードが必須（AWS VPC CNIプラグインを使用）
  cpu                      = var.cpu                                  # タスクに割り当てるCPUユニット 1024ユニット = 1vCPU = 1スレッド（論理コア）相当
  memory                   = var.memory                               # タスクに割り当てるメモリ（MiB）
  execution_role_arn       = var.ecs_task_execution_role_arn          # タスク実行用のIAMロール
  # IAMロールが付与されるのは、タスク定義から起動された「ECSタスク（コンテナ）」
  # ECSタスク　タスク定義（設計図）から実際に起動された「コンテナ群（1つ以上）」の実体 ＝ 実際に動いているアプリケーションのプロセス
  # ECS上で管理される　"arn:aws:ecs:ap-northeast-1:258632448142:task-definition/nestjs-hannibal-3-api-task:7"

  # (オプション) タスクロール (アプリケーションがAWSサービスにアクセスする場合)
  # task_role_arn            = aws_iam_role.ecs_task_role.arn # 別途作成

  # コンテナの定義（イメージ、ポート、環境変数など）
  # コンテナは、アプリケーションの実行環境を提供します
  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container" # コンテナ名
      image     = "${var.ecr_repository_url}:latest" # ECRから取得するDockerイメージ（初期値）
      cpu       = var.cpu                         # コンテナに割り当てるCPUユニット
      memory    = var.memory                      # コンテナに割り当てるメモリ
      essential = true                            # このコンテナが必須かどうか
      portMappings = [
        {
          containerPort = var.container_port # コンテナ内部でリッスンしているアプリのポート番号と揃える
          hostPort      = var.container_port # ここでの「ホスト」は、Fargateタスクごとに割り当てられるENI（Elastic Network Interface）を指すと考えてください 
          protocol      = "tcp"
        } # 外部からの通信は、ENIのIPアドレス＋hostPortに届き、そこからcontainerPortにマッピングされてコンテナ内のアプリに届きます
      ]
      environment = [                                            # コンテナ内部のアプリに渡す環境変数
        { name = "PORT", value = tostring(var.container_port) }, # アプリケーションがリッスンするポート
        # tostring 値を文字列型に変換する関数 多くのアプリケーションや設定ファイルでは、環境変数の値は文字列として扱われるため

        { name = "HOST", value = "0.0.0.0" },
        # 0.0.0.0 アプリケーションは「そのコンテナに割り当てられているすべてのネットワークインターフェース（IPアドレス）」でリッスン（待ち受け）するという意味になります
        # 127.0.0.1 コンテナの中からしかアクセスできなくなります

        { name = "NODE_ENV", value = "production" },             # 本番環境
        { name = "CLIENT_URL", value = var.client_url_for_cors }, # CORS設定用のフロントエンドURL
        { name = "DATABASE_URL", value = "postgresql://${var.db_username}:${var.db_password}@${var.rds_endpoint}/${var.db_name}?sslmode=require&sslrootcert=/opt/rds-ca-2019-root.pem" }
        # 他に必要な環境変数があれば追加
      ]
      logConfiguration = {    # CloudWatch Logs設定
        logDriver = "awslogs" # AWS CloudWatch Logsドライバーを使用
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-api-task" # ここでログストリームも自動で作られる
          "awslogs-region"        = var.aws_region                      # AWSリージョン
          "awslogs-stream-prefix" = "ecs"                               # ログストリームのプレフィックス
        }
      }
    }
  ])
}

# --- CloudWatch Log Group for ECS Task ---
# ECSタスクのログを保存するCloudWatch Logsのロググループを作成
# ロググループは、ログストリームをグループ化するためのコンテナです
# amazonq-ignore-next-line
resource "aws_cloudwatch_log_group" "ecs_api_task_logs" {
  name              = "/ecs/${var.project_name}-api-task" # ロググループ名
  retention_in_days = 7                                   # retention: 保持
}

# ECS Native Blue/Green uses built-in service linking
# No additional IAM roles required for basic deployment

# --- ECS Service with CodeDeploy Blue/Green ---
resource "aws_ecs_service" "api" {
  name                              = "${var.project_name}-api-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.api.arn
  desired_count                     = var.desired_task_count
  launch_type                       = "FARGATE"
  # Blue初期Healthy化のため猶予延長
  health_check_grace_period_seconds = 180
  
  deployment_controller {
    type = "CODE_DEPLOY"
  }
  
  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = var.blue_target_group_arn
    # コンテナ名とポートはタスク定義と一致させる必要がある
    container_name   = "${var.project_name}-container"  # タスク定義のcontainerDefinitions[0].name
    container_port   = var.container_port                # タスク定義のportMappings[0].containerPort
  }
  
  depends_on = [var.alb_listener_http_arn, var.alb_listener_test_arn, var.rds_endpoint]
  
  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}