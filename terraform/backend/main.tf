# terraform/backend/main.tf

# --- VPC Data Sources (既存のVPCとサブネットを使用する場合) ---
# dataソースは、「AWS上にすでに存在するVPCの情報を自動で取得する」ためのものです
data "aws_vpc" "selected" { # AWSのVPC情報を取得して、selectedという名前でTerraform内から参照できるようにした
  # id = var.vpc_id # vpc_id を直接指定する場合
  default = true # デフォルトVPCを自動で探して、その情報（IDなど）を取得(なければエラー)
}

# これは「AWSにすでに存在するサブネットの情報のリストを、publicという名前で取得する」という宣言です
# ALBやECSなどは、そのリスト全部を指定して「複数AZ分散」を自動的にやってくれる
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  # 必要に応じてタグなどで絞り込み
  # tags = {
  #   Tier = "Public"
  # }
}

# --- IAM Role for ECS Task ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  # (オプション) タスクロール (アプリケーションがAWSサービスにアクセスする場合)
  # task_role_arn            = aws_iam_role.ecs_task_role.arn # 別途作成

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container"
      image     = var.container_image_uri
      cpu       = var.cpu
      memory    = var.memory
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port # awsvpcモードではhostPortとcontainerPortは同じ
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "PORT", value = tostring(var.container_port) },
        { name = "HOST", value = "0.0.0.0" },
        { name = "NODE_ENV", value = "production" },
        { name = "CLIENT_URL", value = var.client_url_for_cors }
        # 他に必要な環境変数があれば追加
      ]
      logConfiguration = { # CloudWatch Logs設定
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-api-task"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# --- CloudWatch Log Group for ECS Task ---
resource "aws_cloudwatch_log_group" "ecs_api_task_logs" {
  name              = "/ecs/${var.project_name}-api-task"
  retention_in_days = 7 # ログ保持期間 (適宜変更)
}

# --- Application Load Balancer (ALB) ---
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false # public facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.public.ids # public_subnet_ids を使用

  enable_deletion_protection = false # 開発中はfalse推奨
}

# --- ALB Target Group ---
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id # data.aws_vpc.selected.id を使用
  target_type = "ip"                     # Fargateの場合はip

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399" # GraphQLのエンドポイントなら200または400番台が返る場合も考慮
  }
}

# --- ALB Listener ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_listener_port
  protocol          = "HTTP" # HTTPSの場合は "HTTPS" と certificate_arn が必要

  # (オプション) HTTPS リスナーの場合
  # certificate_arn   = var.certificate_arn
  # ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# --- Security Group for ALB ---
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = data.aws_vpc.selected.id # data.aws_vpc.selected.id を使用

  ingress {
    from_port   = var.alb_listener_port
    to_port     = var.alb_listener_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 全開放 (HTTPSの場合は443も)
  }

  # HTTPSの場合
  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security Group for ECS Fargate Service ---
resource "aws_security_group" "ecs_service_sg" {
  name        = "${var.project_name}-ecs-service-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = data.aws_vpc.selected.id # data.aws_vpc.selected.id を使用

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # ALBからの通信のみ許可
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # インターネットへのアウトバウンド (ECR pullなど)
  }
}

# --- ECS Service ---
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_task_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids # Fargateタスクを配置するサブネット (ALBからのアクセスがあるためパブリックサブネットに置くか、プライベートサブネット＋NAT Gateway)
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true # パブリックサブネットに配置し、ECRからイメージをpullするためにtrue (プライベートサブネット＋NAT Gatewayの場合はfalse)
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
  }

  # (オプション) サービスディスカバリやデプロイ設定
  # health_check_grace_period_seconds = 60
  # deployment_controller {
  #   type = "ECS"
  # }

  depends_on = [aws_lb_listener.http] # ALBリスナー作成後にサービスを開始
}
