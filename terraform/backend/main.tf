# terraform/backend/main.tf

# --- VPC Data Sources (既存のVPCとサブネットを使用する場合) ---
# dataソースは、「AWS上にすでに存在するVPCの情報を自動で取得する」ためのものです
# これにより、手動でVPC IDを指定する代わりに、Terraformが自動的にVPC情報を取得できます
# provider.tf でリージョン指定している
data "aws_vpc" "selected" { # AWSのVPC情報を取得して、selectedという名前でTerraform内から参照できるようにした
  # id = var.vpc_id # vpc_id を直接指定する場合
  default = true # デフォルトVPCを自動で探して、その情報（IDなど）を取得(なければエラー)
  # デフォルトVPCは、AWSアカウント作成時に自動的に作成されるVPCです
  # 通常、パブリックサブネットが含まれており、開発環境での使用に適しています
  # 各リージョンにはデフォルトVPCが1つ自動で用意されています（削除も可能）
  # それとは別に、1つのリージョン内で複数のVPCを自分で作成することも可能です
}

# これは「AWSにすでに存在するサブネットの情報のリストを、publicという名前で取得する」という宣言です
# ALBやECSなどは、そのリスト全部を指定して「複数AZ分散」を自動的にやってくれる
# 複数のAZにまたがることで、高可用性を確保できます
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"                   # 任意の文字列ではなく、AWSが認識できる属性名のみが有効です
    values = [data.aws_vpc.selected.id] # 先ほど取得したVPCのIDを使用
  }
  # 必要に応じてタグなどで絞り込み
  # tags = {
  #   Tier = "Public" # パブリックサブネットのみを取得する場合
  # }
}
# data.aws_subnets.public.ids で[ "subnet-xxxx", "subnet-yyyy", ... ] のようなリストが取得できます


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

# --- IAM User Permissions for hannibal user ---
# ※ 既存の手動アタッチ済みマネージドポリシーはAWSコンソールで一度detachし、Terraformで管理してください
# ※ 10個制限を超えないよう、不要なものはアタッチしない・カスタムポリシーに統合する

# dataソースではなく直接ユーザー名を指定（iam:GetUser権限不要）

# --- IAM Custom Policy (権限統合) ---
resource "aws_iam_policy" "hannibal_terraform_policy" {
  name        = "HannibalInfraAdminPolicy"
  description = "Custom policy for Terraform ECS deployment - ECR, CloudWatch, ELB, EC2, ECS, IAM, S3, CloudFront permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR権限 (Container Registry管理)
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:GetLifecyclePolicy",
          "ecr:PutLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:ListTagsForResource"
        ]
        Resource = "arn:aws:ecr:ap-northeast-1:258632448142:repository/nestjs-hannibal-3"
      },
      {
        # CloudWatch Logs権限 (ログ管理)
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
          "logs:DeleteLogGroup",
          # GitHub Actions用の追加権限
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        # ELB権限 (Load Balancer管理)
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          # GitHub Actions用の追加権限
          "elbv2:DescribeLoadBalancers",
          "elbv2:DeleteLoadBalancer",
          "elbv2:DescribeTargetGroups",
          "elbv2:DeleteTargetGroup",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeListenerAttributes"
        ]
        Resource = "*"
      },
      {
        # EC2権限 (VPC, Subnet, SG, ENI)
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeAddresses",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          # GitHub Actions用の追加権限
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        # ECS権限 (Cluster, Service, Task Definition)
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:ListClusters",
          "ecs:DescribeServices",
          "ecs:ListServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DeleteCluster",
          "ecs:CreateCluster",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ]
        Resource = "*"
      },
      {
        # IAM権限 (Terraform用ロール・ポリシー管理)
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:GetUser",
          # GitHub Actions用の追加権限
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion"
        ]
        Resource = "*"
      },
      {
        # S3バケット・オブジェクト操作権限
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*"
        ]
      },
      {
        # CloudFrontディストリビューション・キャッシュ無効化権限
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListDistributions",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "hannibal_terraform_policy" {
  user       = "hannibal" # 直接ユーザー名を指定
  policy_arn = aws_iam_policy.hannibal_terraform_policy.arn
}

# --- 一時的な権限追加（権限エラー解決用）---
# ※ このポリシーは問題解決後に削除予定
resource "aws_iam_user_policy_attachment" "hannibal_ec2_read_only_temp" {
  user       = "hannibal"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "hannibal_ecs_read_only_temp" {
  user       = "hannibal"
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

# --- 既存のマネージドポリシーは不要になったため削除 ---
# resource "aws_iam_user_policy_attachment" "hannibal_ec2_full" { ... }
# resource "aws_iam_user_policy_attachment" "hannibal_ecs_full" { ... }

# --- IAM Role for ECS Task ---
# ECSタスクがAWSのサービス（例：ECRからイメージのpullなど）にアクセスするためのIAMロールを作成
# このロールは、ECSタスクがAWSのサービスを利用する際の認証に使用されます
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role" # プロジェクト名をプレフィックスとして使用

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
      image     = var.container_image_uri         # ECRから取得するDockerイメージ
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
        { name = "CLIENT_URL", value = var.client_url_for_cors } # CORS設定用のフロントエンドURL
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
resource "aws_cloudwatch_log_group" "ecs_api_task_logs" {
  name              = "/ecs/${var.project_name}-api-task" # ロググループ名
  retention_in_days = 7                                   # retention: 保持
}

# --- ALB (Application Load Balancer) ---
resource "aws_lb" "main" {
  name                       = "${var.project_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = data.aws_subnets.public.ids
  enable_deletion_protection = false
}

# --- ALB Target Group ---
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "ip"
  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

# --- ALB Listener ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_listener_port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# --- Security Group for ALB ---
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = data.aws_vpc.selected.id
  ingress {
    from_port   = var.alb_listener_port
    to_port     = var.alb_listener_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security Group for ECS Service ---
resource "aws_security_group" "ecs_service_sg" {
  name        = "${var.project_name}-ecs-service-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = data.aws_vpc.selected.id
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
  }
  depends_on = [aws_lb_listener.http]
}
