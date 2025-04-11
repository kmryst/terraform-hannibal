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
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a" # 必要に応じてリージョン内の別AZに変更可

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

  # HTTP (80) からのインバウンドトラフィックを許可 (CloudFrontから)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # より厳密にはCloudFrontのIPレンジを指定することも可能
  }

  # HTTPS (443) からのインバウンドトラフィックを許可 (CloudFrontから)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # より厳密にはCloudFrontのIPレンジを指定することも可能
  }

  # NestJS (3000) からのインバウンドトラフィックを許可
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # API直接アクセスを許可する場合。CloudFront経由のみなら不要かも
  }

  # SSH (22) からのインバウンドトラフィックは特定のIPアドレスからのみ許可
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_address] # 必ず自分のIPアドレス範囲に限定してください
  }

  # 全てのアウトバウンドトラフィックを許可
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

# --- ここからIAMロール関連の修正 ---

# EC2インスタンス用のIAMロールを作成
resource "aws_iam_role" "ec2_role" {
  name = var.ec2_iam_role_name # 変数で指定された名前 (例: "SSMInstanceProfile") でロールを作成

  # EC2サービスがこのロールを引き受けることを許可するポリシー
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role" # タグは任意で設定
  }
}

# 作成したロールにSSMを利用するための管理ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2インスタンスプロファイルを作成
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name # ★修正点: 作成したリソースを参照
}

# --- IAMロール関連の修正 ここまで ---


# EC2インスタンス
resource "aws_instance" "backend" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  key_name               = var.ec2_key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name # 作成したインスタンスプロファイルを参照

  # user_dataを使用して起動時にSSMエージェントをインストール・有効化
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              # Amazon Linux 2023以降はSSMエージェントがプリインストールされている場合が多い
              # 必要に応じてインストールコマンドを追加 (例: dnf install -y amazon-ssm-agent)
              systemctl enable amazon-ssm-agent --now # エージェントの有効化と起動

              # Node.js, npm, git, pm2 のインストール (環境に合わせて調整)
              dnf install -y nodejs git # Amazon Linux 2023 の場合 nodejs は core リポジトリに含まれる
              npm install -g npm@latest # npm を最新に更新
              npm install -g pm2

              # --- アプリケーションのデプロイや設定をここに追加 ---

              EOF

  tags = {
    Name = "${var.project_name}-backend"
  }
}

# S3バケット（フロントエンド用）
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-bucket" # バケット名はグローバルで一意である必要あり

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

# S3バケットの所有権設定 (ACL無効化を推奨)
resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    object_ownership = "BucketOwnerEnforced" # ACLを無効化し、バケット所有者が全オブジェクトを所有
  }
}

# S3バケット公開ブロック設定 (デフォルトで有効な場合が多いが明示)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true # BucketOwnerEnforced のため true に設定
  block_public_policy     = true
  ignore_public_acls      = true # BucketOwnerEnforced のため true に設定
  restrict_public_buckets = true
}

# CloudFront OAC（Origin Access Control）
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for ${var.project_name} frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3バケットポリシー（CloudFront OACからのアクセスのみ許可）
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17" # または "2008-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly" # ステートメントIDを追加
        Action    = "s3:GetObject"
        Effect    = "Allow"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            # CloudFront ディストリビューションの ARN を参照
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
  # CloudFrontディストリビューション作成後にポリシーが適用されるように依存関係を設定
  depends_on = [
    aws_cloudfront_origin_access_control.frontend,
    aws_cloudfront_distribution.frontend
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

  # 別のオリジンとしてEC2を追加（APIサーバー用）
  origin {
    domain_name = aws_instance.backend.public_dns # EC2インスタンスのパブリックDNS名
    origin_id   = "${var.project_name}-ec2-backend" # オリジンIDは任意だがわかりやすく

    custom_origin_config {
      http_port              = 3000 # ★NestJSがリッスンしているポートに変更
      https_port             = 443  # HTTPSを使う場合は設定が必要
      origin_protocol_policy = "http-only" # ★NestJSがHTTPでリッスンしているため
      origin_ssl_protocols   = ["TLSv1.2"] # https-onlyの場合に有効
      origin_read_timeout    = 30
      origin_keepalive_timeout = 5
    }
  }

  # S3コンテンツ用のデフォルトキャッシュ動作
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"] # OPTIONSもキャッシュするとCORSに影響する場合あり注意
    target_origin_id = aws_s3_bucket.frontend.id # S3オリジンID

    # Cache policy and origin request policy (Managed policies)
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin
    viewer_protocol_policy   = "redirect-to-https"
  }

  # API用のキャッシュ動作（/api/*）
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"] # APIは通常キャッシュしないことが多い
    target_origin_id = "${var.project_name}-ec2-backend" # EC2オリジンID

    # Cache policy and origin request policy (Managed policies or custom)
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewerExceptHostHeader (CORSヘッダ等も転送)
    viewer_protocol_policy   = "redirect-to-https"
  }

  # SPAルーティング対応のためのエラーレスポンス設定
  custom_error_response {
    error_code         = 403 # Forbidden
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 10 # エラーページのキャッシュ時間
  }

  custom_error_response {
    error_code         = 404 # Not Found
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 10 # エラーページのキャッシュ時間
  }

  restrictions {
    geo_restriction {
      restriction_type = "none" # 必要に応じて 'whitelist' や 'blacklist' を設定
      # locations        = ["JP", "US"] # whitelistの場合の例
    }
  }

  # CloudFrontが提供するデフォルトの証明書を使用 (*.cloudfront.net)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # 代わりにACM証明書を使用する場合 (コメントアウト解除して設定)
  # viewer_certificate {
  #   acm_certificate_arn = var.acm_certificate_arn # ACM証明書のARNを変数で指定
  #   ssl_support_method  = "sni-only"
  #   minimum_protocol_version = "TLSv1.2_2021"
  # }
  # aliases = [var.custom_domain_name] # カスタムドメイン名も変数で指定

  tags = {
    Name = "${var.project_name}-cloudfront"
  }

  # EC2インスタンスが作成されてからCloudFrontが作成されるように依存関係を設定
  depends_on = [aws_instance.backend]
}
