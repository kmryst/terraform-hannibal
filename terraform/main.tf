
# C:\code\javascript\nestjs-hannibal-3\terraform\main.tf

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.project_name != "" ? "${var.project_name}-vpc" : "default-vpc-name"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name = var.project_name != "" ? "${var.project_name}-public-subnet" : "default-public-subnet-name"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.project_name != "" ? "${var.project_name}-igw" : "default-igw-name"
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
    Name = var.project_name != "" ? "${var.project_name}-public-rt" : "default-public-rt-name"
  }
}

# サブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# EC2用セキュリティグループ
resource "aws_security_group" "ec2" {
  name        = var.project_name != "" ? "${var.project_name}-ec2-sg" : "default-ec2-sg-name"
  description = "Security group for NestJS backend EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000 # NestJSポート
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22 # SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_address]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.project_name != "" ? "${var.project_name}-ec2-sg" : "default-ec2-sg-name"
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
  tags = { Name = var.project_name != "" ? "${var.project_name}-ec2-role" : "default-ec2-role-name" }
}

# ロールにSSM管理ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2インスタンスプロファイル
resource "aws_iam_instance_profile" "ec2_profile" {
  name = var.project_name != "" ? "${var.project_name}-ec2-profile" : "default-ec2-profile-name"
  role = aws_iam_role.ec2_role.name
}

# Elastic IP (Provider v5.0.0 以上対応)
resource "aws_eip" "backend_eip" {
  domain = "vpc"
  tags = {
    Name = var.project_name != "" ? "${var.project_name}-backend-eip" : "default-backend-eip-name"
  }
}

# EC2インスタンス
resource "aws_instance" "backend" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  key_name               = var.ec2_key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "Starting user data script..."
              # Amazon Linux 2023 uses dnf
              dnf update -y
              echo "Installing Git..."
              dnf install -y git
              echo "Git version: $(git --version)"
              echo "Installing nvm, Node.js, and npm for ec2-user..."
              sudo -u ec2-user bash -i -c 'echo "Running as user: $(whoami)"; curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash; export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; nvm install --lts; nvm use --lts; nvm alias default "lts/*"; echo "Node.js version: $(node -v)"; echo "npm version: $(npm -v)"'
              echo "Installing PM2 globally for ec2-user..."
              sudo -u ec2-user bash -i -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; npm install -g pm2; echo "PM2 version: $(pm2 -v)"'
              echo "Creating symbolic links in /usr/local/bin..."
              NVM_DIR="/home/ec2-user/.nvm"; NODE_VERSION=$(sudo -u ec2-user bash -i -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; ls $NVM_DIR/versions/node/ | grep "^v" | sort -V | tail -n 1'); NODE_PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin/node"; NPM_PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin/npm"; PM2_PATH=$(sudo -u ec2-user bash -i -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; npm root -g')/pm2/bin/pm2
              if [ -n "$NODE_PATH" ] && [ -e "$NODE_PATH" ]; then sudo ln -sf $NODE_PATH /usr/local/bin/node; echo "node symlink created."; else echo "Node path not found or empty: $NODE_PATH"; fi
              if [ -n "$NPM_PATH" ] && [ -e "$NPM_PATH" ]; then sudo ln -sf $NPM_PATH /usr/local/bin/npm; echo "npm symlink created."; else echo "npm path not found or empty: $NPM_PATH"; fi
              if [ -n "$PM2_PATH" ] && [ -e "$PM2_PATH" ]; then sudo ln -sf $PM2_PATH /usr/local/bin/pm2; echo "pm2 symlink created."; else echo "pm2 path not found or empty: $PM2_PATH"; fi
              echo "Setting up PM2 startup script..."; STARTUP_CMD=$(sudo -u ec2-user bash -i -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; pm2 startup systemd -u ec2-user --hp /home/ec2-user' | grep 'sudo env')
              if [ -n "$STARTUP_CMD" ]; then sudo bash -c "$STARTUP_CMD"; echo "PM2 startup script configured."; else echo "Failed to generate PM2 startup command."; fi
              echo "Ensuring SSM Agent is installed and running..."; sudo systemctl enable amazon-ssm-agent --now; sudo systemctl status amazon-ssm-agent || echo "SSM Agent status check failed."
              echo "User data script finished."
              EOF

  tags = {
    Name = var.project_name != "" ? "${var.project_name}-backend" : "default-backend-name"
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
  bucket = var.project_name != "" ? "${var.project_name}-frontend-bucket" : "default-frontend-bucket-name" # バケット名はグローバルに一意である必要あり
  tags = { Name = var.project_name != "" ? "${var.project_name}-frontend" : "default-frontend-name" }
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
  name                              = var.project_name != "" ? "${var.project_name}-oac" : "default-oac-name"
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
    aws_cloudfront_distribution.frontend
  ]
}

# --- CloudFrontディストリビューション (修正済み) ---
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = var.project_name != "" ? "${var.project_name} distribution" : "Default distribution comment"

  origin { # S3オリジン
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.frontend.id
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin { # EC2オリジン
    # 修正箇所: Elastic IPのパブリックDNS名を使用する
    domain_name = aws_eip.backend_eip.public_dns
    origin_id   = var.project_name != "" ? "${var.project_name}-ec2-backend" : "default-ec2-backend-origin-id"

    custom_origin_config {
      http_port              = 3000
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
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
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = var.project_name != "" ? "${var.project_name}-ec2-backend" : "default-ec2-backend-origin-id"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewerExceptHostHeader
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = var.project_name != "" ? "${var.project_name}-cloudfront" : "default-cloudfront-name"
  }

  # EIP の関連付け (association) が完了してから CloudFront を作成/更新
  depends_on = [aws_eip_association.backend_eip_assoc]
}

