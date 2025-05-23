# terraform/backend/main.tf

# --- VPC Data Sources (既存のVPCとサブネットを使用する場合) ---
# dataソースは、「AWS上にすでに存在するVPCの情報を自動で取得する」ためのものです
# これにより、手動でVPC IDを指定する代わりに、Terraformが自動的にVPC情報を取得できます
data "aws_vpc" "selected" { # AWSのVPC情報を取得して、selectedという名前でTerraform内から参照できるようにした
  # id = var.vpc_id # vpc_id を直接指定する場合
  default = true # デフォルトVPCを自動で探して、その情報（IDなど）を取得(なければエラー)
  # デフォルトVPCは、AWSアカウント作成時に自動的に作成されるVPCです
  # 通常、パブリックサブネットが含まれており、開発環境での使用に適しています
}

# これは「AWSにすでに存在するサブネットの情報のリストを、publicという名前で取得する」という宣言です
# ALBやECSなどは、そのリスト全部を指定して「複数AZ分散」を自動的にやってくれる
# 複数のAZにまたがることで、高可用性を確保できます
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id] # 先ほど取得したVPCのIDを使用
  }
  # 必要に応じてタグなどで絞り込み
  # tags = {
  #   Tier = "Public" # パブリックサブネットのみを取得する場合
  # }
}

# --- IAM Role for ECS Task ---
# ECSタスクがAWSのサービス（例：CloudWatch Logs）にアクセスするためのIAMロールを作成
# このロールは、ECSタスクがAWSのサービスを利用する際の認証に使用されます
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role" # プロジェクト名をプレフィックスとして使用

  # このロールをECSタスクが引き受けることができるようにするポリシー
  # assume_role_policyは、どのAWSサービスがこのロールを引き受けることができるかを定義します
  assume_role_policy = jsonencode({
    Version = "2012-10-17", # IAMポリシーのバージョン
    Statement = [
      {
        Action = "sts:AssumeRole", # ロールを引き受けるためのアクション
        Effect = "Allow",          # 許可する
        Principal = {
          Service = "ecs-tasks.amazonaws.com" # ECSタスクサービスがこのロールを引き受けられる
        }
      }
    ]
  })
}

# ECSタスク実行ロールに、CloudWatch Logsへの書き込み権限などを付与
# このポリシーにより、ECSタスクはCloudWatch Logsにログを書き込むことができます
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name # 先ほど作成したロール
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" # AWSが提供するマネージドポリシー
}

# --- ECS Cluster ---
# ECSクラスタを作成（Fargateタスクを実行するための論理的なグループ）
# クラスタは、タスクやサービスを論理的にグループ化するためのコンテナです
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster" # プロジェクト名をプレフィックスとして使用
}

# --- ECS Task Definition ---
# ECSタスクの定義（コンテナの設定、CPU、メモリ、環境変数など）
# タスク定義は、コンテナの実行に必要な設定を定義します
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api-task" # タスク定義のファミリー名
  requires_compatibilities = ["FARGATE"] # Fargateで実行することを指定（サーバーレスコンピューティング）
  network_mode             = "awsvpc"    # Fargateではawsvpcモードが必須（AWS VPC CNIプラグインを使用）
  cpu                      = var.cpu     # タスクに割り当てるCPUユニット（例：256 = 0.25 vCPU）
  memory                   = var.memory  # タスクに割り当てるメモリ（MiB）
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # タスク実行用のIAMロール
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
          containerPort = var.container_port # コンテナがリッスンするポート
          hostPort      = var.container_port # ホストがリッスンするポート（awsvpcモードでは同じ）
          protocol      = "tcp"              # プロトコル
        }
      ]
      environment = [
        { name = "PORT", value = tostring(var.container_port) }, # アプリケーションがリッスンするポート
        { name = "HOST", value = "0.0.0.0" },                    # すべてのインターフェースでリッスン
        { name = "NODE_ENV", value = "production" },             # 本番環境
        { name = "CLIENT_URL", value = var.client_url_for_cors } # CORS設定用のフロントエンドURL
        # 他に必要な環境変数があれば追加
      ]
      logConfiguration = { # CloudWatch Logs設定
        logDriver = "awslogs" # AWS CloudWatch Logsドライバーを使用
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-api-task" # ロググループ名
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
  retention_in_days = 7 # ログ保持期間 (適宜変更)
  # ログの保持期間を設定することで、ストレージコストを最適化できます
}

# --- Application Load Balancer (ALB) ---
# フロントエンドからのリクエストを受け付けるALBを作成
# ALBは、トラフィックを複数のターゲットに分散するためのロードバランサーです
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb" # ALBの名前
  internal           = false # public facing（インターネットからアクセス可能）
  load_balancer_type = "application" # アプリケーションロードバランサー
  security_groups    = [aws_security_group.alb_sg.id] # セキュリティグループ
  subnets            = data.aws_subnets.public.ids # パブリックサブネットに配置

  enable_deletion_protection = false # 開発中はfalse推奨（本番環境ではtrueに設定）
}

# --- ALB Target Group ---
# ALBがリクエストを転送する先のターゲットグループを作成
# ターゲットグループは、リクエストの転送先を定義します
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-tg" # ターゲットグループ名
  port        = var.container_port       # ターゲットのポート
  protocol    = "HTTP"                   # プロトコル
  vpc_id      = data.aws_vpc.selected.id # VPC ID
  target_type = "ip"                     # Fargateの場合はip（コンテナのIPアドレス）

  # ヘルスチェックの設定（ECSタスクが正常に動作しているか確認）
  # ヘルスチェックは、ターゲットの健全性を監視します
  health_check {
    enabled             = true
    path                = var.health_check_path # ヘルスチェックのパス
    protocol            = "HTTP"                # プロトコル
    port                = "traffic-port"        # トラフィックポート
    healthy_threshold   = 3                     # 正常と判断するまでの成功回数
    unhealthy_threshold = 3                     # 異常と判断するまでの失敗回数
    timeout             = 5                     # タイムアウト（秒）
    interval            = 30                    # チェック間隔（秒）
    matcher             = "200-399" # GraphQLのエンドポイントなら200または400番台が返る場合も考慮
  }
}

# --- ALB Listener ---
# ALBがリクエストを受け付けるポートとプロトコルを設定
# リスナーは、特定のポートでリクエストを受け付けます
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn # ALBのARN
  port              = var.alb_listener_port # リスナーのポート
  protocol          = "HTTP" # プロトコル（HTTPSの場合は "HTTPS" と certificate_arn が必要）

  # (オプション) HTTPS リスナーの場合
  # certificate_arn   = var.certificate_arn # ACM証明書のARN
  # ssl_policy        = "ELBSecurityPolicy-2016-08" # SSLポリシー

  # リクエストをターゲットグループに転送
  # デフォルトアクションは、リクエストの転送先を定義します
  default_action {
    type             = "forward" # 転送アクション
    target_group_arn = aws_lb_target_group.api.arn # ターゲットグループのARN
  }
}

# --- Security Group for ALB ---
# ALBのセキュリティグループ（HTTP/HTTPSのインバウンドトラフィックを許可）
# セキュリティグループは、インスタンスレベルでのファイアウォールとして機能します
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg" # セキュリティグループ名
  description = "Allow HTTP/HTTPS traffic to ALB" # 説明
  vpc_id      = data.aws_vpc.selected.id # VPC ID

  # HTTPのインバウンドトラフィックを許可
  # インバウンドルールは、インスタンスへの受信トラフィックを制御します
  ingress {
    from_port   = var.alb_listener_port # 開始ポート
    to_port     = var.alb_listener_port # 終了ポート
    protocol    = "tcp"                 # プロトコル
    cidr_blocks = ["0.0.0.0/0"] # 全開放 (HTTPSの場合は443も)
  }

  # HTTPSの場合
  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # アウトバウンドトラフィックを許可（ECSタスクへの通信など）
  # アウトバウンドルールは、インスタンスからの送信トラフィックを制御します
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # すべてのプロトコル
    cidr_blocks = ["0.0.0.0/0"] # すべてのIPアドレス
  }
}

# --- Security Group for ECS Fargate Service ---
# ECSタスクのセキュリティグループ（ALBからのインバウンドトラフィックを許可）
# このセキュリティグループは、ECSタスクのネットワークアクセスを制御します
resource "aws_security_group" "ecs_service_sg" {
  name        = "${var.project_name}-ecs-service-sg" # セキュリティグループ名
  description = "Allow traffic from ALB to ECS tasks" # 説明
  vpc_id      = data.aws_vpc.selected.id # VPC ID

  # ALBからのインバウンドトラフィックを許可
  # このルールにより、ALBからのリクエストのみがECSタスクに到達できます
  ingress {
    from_port       = var.container_port # 開始ポート
    to_port         = var.container_port # 終了ポート
    protocol        = "tcp"              # プロトコル
    security_groups = [aws_security_group.alb_sg.id] # ALBからの通信のみ許可
  }

  # アウトバウンドトラフィックを許可（ECRからイメージをpullするなど）
  # このルールにより、ECSタスクはインターネットにアクセスできます
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # すべてのプロトコル
    cidr_blocks = ["0.0.0.0/0"] # すべてのIPアドレス
  }
}

# --- ECS Service ---
# ECSサービスを作成（タスクの実行、スケーリング、ALBとの連携など）
# サービスは、タスクの実行を管理し、指定された数のタスクを維持します
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-service" # サービス名
  cluster         = aws_ecs_cluster.main.id           # ECSクラスタ
  task_definition = aws_ecs_task_definition.api.arn   # タスク定義
  desired_count   = var.desired_task_count            # 実行するタスクの数
  launch_type     = "FARGATE"                         # 起動タイプ

  # ネットワーク設定（サブネット、セキュリティグループ、パブリックIPの割り当て）
  # この設定により、ECSタスクのネットワーク環境を制御します
  network_configuration {
    subnets          = data.aws_subnets.public.ids # Fargateタスクを配置するサブネット
    security_groups  = [aws_security_group.ecs_service_sg.id] # セキュリティグループ
    assign_public_ip = true # パブリックIPの割り当て（ECRからイメージをpullするために必要）
  }

  # ALBとの連携設定
  # この設定により、ALBからのリクエストをECSタスクに転送します
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn # ターゲットグループ
    container_name   = "${var.project_name}-container" # コンテナ名
    container_port   = var.container_port # コンテナポート
  }

  # (オプション) サービスディスカバリやデプロイ設定
  # health_check_grace_period_seconds = 60 # ヘルスチェックの猶予期間
  # deployment_controller {
  #   type = "ECS" # デプロイメントコントローラーのタイプ
  # }

  depends_on = [aws_lb_listener.http] # ALBリスナー作成後にサービスを開始
  # この依存関係により、ALBが完全に設定された後にECSサービスが開始されます
}
