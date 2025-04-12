# C:\code\javascript\nestjs-hannibal-3\terraform\main.tf

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # EIPを使う場合でも、一時的なIPは割り当てられる
  availability_zone       = "ap-northeast-1a" # 必要に応じて変更

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# サブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# EC2用セキュリティグループ
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for NestJS backend EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # CloudFrontからのアクセス
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # CloudFrontからのアクセス
  }
  ingress {
    from_port   = 3000 # NestJSポート
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # CloudFront または直接アクセス用
  }
  ingress {
    from_port   = 22 # SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_address] # 自分のIPアドレスに限定
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# EC2インスタンス用のIAMロール
resource "aws_iam_role" "ec2_role" {
  name = var.ec2_iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-ec2-role" }
}

# ロールにSSM管理ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2インスタンスプロファイル
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# --- Elastic IP を修正 ---
resource "aws_eip" "backend_eip" {
  # domain   = "vpc" # この行を削除またはコメントアウト
  vpc      = true   # この行を追加

  tags = {
    Name = "${var.project_name}-backend-eip"
  }
}
# --- 修正ここまで ---

# EC2インスタンス
resource "aws_instance" "backend" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  key_name               = var.ec2_key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # user_data は前回の修正内容を維持 (Git, nvm, Node.js, PM2のインストール)
  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "Starting user data script..."
              yum update -y
              echo "Installing Git..."
              yum install -y git
              echo "Git version: $(git --version)"
              echo "Installing nvm, Node.js, and npm for ec2-user..."
              sudo -u ec2-user bash -i -c 'echo "Running as user: $(whoami)"; curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash; export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; nvm install --lts; nvm use --lts; nvm alias default "lts/*"; echo "Node.js version: $(node -v)"; echo "npm version: $(npm -v)"'
              echo "Installing PM2 globally for ec2-user..."
              sudo -u ec2-user bash -i -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; npm install -g pm2; echo "PM2 version: $(pm2 -v)"'
              echo "Creating symbolic links in /usr/local/bin..."
              NVM_DIR="/home/ec2-user/.nvm"; NODE_VERSION=$(ls $NVM_DIR/versions/node/ | grep '^v' | sort -V | tail -n 1); NODE_PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin/node"; NPM_PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin/npm"; PM2_PATH=$(sudo -u ec2-user bash -i -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; npm root -g')/pm2/bin/pm2
              sudo ln -sf $NODE_PATH /usr/local/bin/node; sudo ln -sf $NPM_PATH /usr/local/bin/npm; sudo ln -sf $PM2_PATH /usr/local/bin/pm2
              echo "Symbolic links created."; echo "node -> $(readlink -f /usr/local/bin/node)"; echo "npm -> $(readlink -f /usr/local/bin/npm)"; echo "pm2 -> $(readlink -f /usr/local/bin/pm2)"
              echo "Setting up PM2 startup script..."; STARTUP_CMD=$(sudo -u ec2-user bash -i -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; pm2 startup systemd -u ec2-user --hp /home/ec2-user' | grep 'sudo env')
              if [ -n "$STARTUP_CMD" ]; then sudo bash -c "$STARTUP_CMD"; echo "PM2 startup script configured."; else echo "Failed to generate PM2 startup command."; fi
              echo "Ensuring SSM Agent is installed and running..."; if ! systemctl is-active --quiet amazon-ssm-agent; then dnf install -y amazon-ssm-agent; systemctl enable amazon-ssm-agent --now; else echo "SSM Agent is already active."; fi; systemctl status amazon-ssm-agent
              echo "User data script finished."
              EOF

  tags = {
    Name = "${var.project_name}-backend"
  }
  depends_on = [aws_internet_gateway.main]
}

# Elastic IP と EC2インスタンスの関連付け
resource "aws_eip_association" "backend_eip_assoc" {
  instance_id   = aws_instance.backend.id
  allocation_id = aws_eip.backend_eip.id
}

# S3バケット（フロントエンド用）
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-bucket"
  tags = { Name = "${var.project_name}-frontend" }
}
resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront OAC
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for ${var.project_name} frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3バケットポリシー
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly",
        Action    = "s3:GetObject",
        Effect    = "Allow",
        Resource  = "${aws_s3_bucket.frontend.arn}/*",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
  depends_on = [
    aws_cloudfront_origin_access_control.frontend,
    aws_cloudfront_distribution.frontend # CloudFrontディストリビューションが先にないとARNが確定しない
  ]
}

# CloudFrontディストリビューション
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.project_name} distribution"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.frontend.id
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin { # EC2オリジン
    domain_name = aws_eip.backend_eip.public_ip # Elastic IP を参照
    origin_id   = "${var.project_name}-ec2-backend"

    custom_origin_config {
      http_port              = 3000 # NestJSポート
      https_port             = 443
      origin_protocol_policy = "http-only" # HTTPのみを許可
      origin_ssl_protocols   = ["TLSv1.2"] # 必要に応じて調整
      origin_read_timeout    = 30
      origin_keepalive_timeout = 5
    }
  }

  default_cache_behavior { # S3用 (デフォルト)
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = aws_s3_bucket.frontend.id
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Cors-S3Origin
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior { # API用 (/api/*)
    path_pattern           = "/api/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"] # APIなのでキャッシュは最小限に
    target_origin_id       = "${var.project_name}-ec2-backend"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewerExceptHostHeader (ヘッダー、クッキー、クエリ文字列を転送)
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # SPA対応: 403/404エラーをindex.htmlにルーティング
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10 # 必要に応じて調整
  }
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10 # 必要に応じて調整
  }

  restrictions {
    geo_restriction {
      restriction_type = "none" # 必要に応じて変更 (whitelist/blacklist)
      # locations        = []
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # カスタムドメインを使用しない場合
    # acm_certificate_arn = var.acm_certificate_arn # カスタムドメインを使用する場合
    # ssl_support_method = "sni-only"              # カスタムドメインを使用する場合
  }

  # aliases = [var.custom_domain_name] # カスタムドメインを使用する場合

  tags = {
    Name = "${var.project_name}-cloudfront"
  }

  # EC2のEIPが確定してからCloudFrontを作成
  depends_on = [aws_eip_association.backend_eip_assoc]
}

# --- variables.tf ファイルの内容（参考） ---
# 以下の変数は variables.tf などで定義されている必要があります
/*
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "nestjs-hannibal-3" # プロジェクト名に合わせて変更
}

variable "your_ip_address" {
  description = "Your public IP address for SSH access (CIDR format)"
  type        = string
  # 例: default = "123.45.67.89/32" # 自身のIPアドレス/32に置き換えてください
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 instance (Amazon Linux 2023)"
  type        = string
  default     = "ami-0b7546e839d7ace12" # 東京リージョンの Amazon Linux 2023 (x86_64) の例。最新を確認してください。
}

variable "ec2_instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t3.micro"
}

variable "ec2_key_name" {
  description = "Name of the EC2 key pair"
  type        = string
  # 例: default = "my-key-pair" # 自身のキーペア名に置き換えてください
}

variable "ec2_iam_role_name" {
  description = "Name for the EC2 IAM role"
  type        = string
  default     = "nestjs-hannibal-3-ec2-role"
}

# カスタムドメインを使用する場合に設定
# variable "acm_certificate_arn" {
#   description = "ARN of the ACM certificate for CloudFront"
#   type        = string
#   default     = "" # 例: "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id" (us-east-1リージョンで発行)
# }

# variable "custom_domain_name" {
#   description = "Custom domain name (CNAME) for CloudFront distribution"
#   type        = string
#   default     = "" # 例: "app.example.com"
# }
*/
