# amazonq-ignore-file


# terraform/backend/main.tf

# --- AWS Professional Environment Configuration ---
locals {
  # 環境別リソース最適化（Netflix/Airbnb/Spotify標準パターン）
  enable_multi_az        = var.environment != "dev"
  enable_backup          = var.environment != "dev"
  backup_retention_days  = var.environment == "prod" ? 7 : 0
  publicly_accessible    = var.environment == "dev"
  deletion_protection    = var.environment == "prod"
}

# --- Three-tier VPC Architecture ---
# VPC and subnets are now created in vpc.tf
# Using new custom VPC instead of default VPC


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

# --- Foundation Resources (基盤リソース) ---
# IAMロール・ポリシーは terraform/foundation/ で管理
# 永続化済み（手動管理・destroy対象外）

# --- Application Resources (アプリケーションリソース) ---

# Note: ECS service role removed - using standard ECS service linking
# Blue/Green deployments will be handled via external deployment tools (CodeDeploy, etc.)

# --- IAM Role for ECS Task ---
# ECSタスクがAWSのサービス（例：ECRからイメージのpullなど）にアクセスするためのIAMロールを作成
# このロールは、ECSタスクがAWSのサービスを利用する際の認証に使用されます
resource "aws_iam_role" "ecs_task_execution_role" {
  name                 = "${var.project_name}-ecs-task-execution-role" # プロジェクト名をプレフィックスとして使用
  permissions_boundary = "arn:aws:iam::258632448142:policy/HannibalECSBoundary"  # ECS専用Permission Boundary

  # このロールをECSタスクが引き受けることができるようにするポリシー
  # assume_role_policyは、どのAWSサービスがこのロールを引き受けることができるかを定義します
  assume_role_policy = jsonencode({ # assume 引き受ける ロールにポリシーをアタッチしている
    Version = "2012-10-17",         # IAMポリシーのバージョン
    Statement = [
      {
        Action = "sts:AssumeRole",
        # ECSタスクがIAMロールを使うとき、裏側でAWS STS（Security Token Service）が「一時的な認証情報」を発行し、そのロールの権限でAWSサービスにアクセスできるようにします
        Effect = "Allow",                     # 許可する
        Principal = {                         # このロールを引き受けることができる「主体」
          Service = "ecs-tasks.amazonaws.com" # ECSタスクサービスがこのロールを引き受けられる
        }
      }
    ]
  })
}

# aws_iam_role_policy_attachment IAMロールにポリシーをアタッチする
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name                               # 先ほど作成したロールの.name 属性
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" # AWSが提供するマネージドポリシー
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
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # タスク実行用のIAMロール
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
        { name = "DATABASE_URL", value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/${var.db_name}?sslmode=require&sslrootcert=/opt/rds-ca-2019-root.pem" }
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

# --- ALB (Application Load Balancer) ---
resource "aws_lb" "main" {
  name                       = "${var.project_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = values(aws_subnet.public)[*].id
  enable_deletion_protection = false
}

# --- ALB Target Group (Blue Environment) ---
resource "aws_lb_target_group" "blue" {
  name        = "${var.project_name}-blue-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# --- ALB Target Group (Green Environment) ---
resource "aws_lb_target_group" "green" {
  name        = "${var.project_name}-green-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# --- ALB Listener (Production) ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_listener_port
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# --- ALB Test Listener (Blue/Green Dark Canary) ---
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"
  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = 100
      }
    }
  }
}

# --- ALB Listener Rules for Blue/Green ---
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
      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = 0
      }
    }
  }
  
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
  
  lifecycle {
    ignore_changes = [action]
  }
}

resource "aws_lb_listener_rule" "test" {
  listener_arn = aws_lb_listener.test.arn
  priority     = 100
  
  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = 0
      }
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
  
  lifecycle {
    ignore_changes = [action]
  }
}



# Security Groups moved to security_groups.tf

# ECS Native Blue/Green uses built-in service linking
# No additional IAM roles required for basic deployment

# --- ECS Service with Native Blue/Green ---
resource "aws_ecs_service" "api" {
  name                              = "${var.project_name}-api-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.api.arn
  desired_count                     = var.desired_task_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60
  
  deployment_controller {
    type = "ECS"
  }
  
  # ECS Native Blue/Green Deployment (Provider 6.8.0)
  # deployment_configuration {
  #   bake_time_in_minutes = 1
  # }
  # Note: deployment_configuration may cause "Unexpected block" error in Provider 6.8.0
  # ECS handles bake time automatically via ALB Priority 100 rules
  
  network_configuration {
    subnets          = values(aws_subnet.app)[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
  }
  
  depends_on = [aws_lb_listener.http, aws_lb_listener.test, aws_db_instance.postgres]
}

# --- RDS Subnet Group ---
resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = values(aws_subnet.data)[*].id
  
  tags = {
    Name        = "${var.project_name} DB subnet group"
    project     = var.project_name
    environment = var.environment
  }
}

# RDS Security Group moved to security_groups.tf

# --- RDS PostgreSQL Instance ---
resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  
  # AWS Professional環境別設定（Netflix/Airbnb/Spotify標準）
  backup_retention_period = local.backup_retention_days
  multi_az               = local.enable_multi_az
  publicly_accessible    = false
  
  # 本番環境のみ有効
  backup_window      = local.enable_backup ? "03:00-04:00" : null
  maintenance_window = local.enable_backup ? "sun:04:00-sun:05:00" : null
  
  skip_final_snapshot = true
  deletion_protection = local.deletion_protection
  
  tags = {
    Name = "${var.project_name}-postgres"
  }
}
