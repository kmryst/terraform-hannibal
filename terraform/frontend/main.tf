# terraform/frontend/main.tf

# --- S3 Bucket for Frontend Static Files ---
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = var.s3_bucket_name
  # (オプション) バージョニングを有効にする場合
  # versioning {
  #   enabled = true
  # }
}

# --- Block Public Access for S3 Bucket ---
resource "aws_s3_bucket_public_access_block" "frontend_bucket_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Upload Frontend Files to S3 ---
# client/dist ディレクトリ内のファイルをS3バケットにアップロード
resource "aws_s3_object" "frontend_files" {
  for_each = fileset(var.frontend_build_path, "**/*.*") # 全てのファイルとサブディレクトリを対象

  bucket = aws_s3_bucket.frontend_bucket.id
  key    = each.value
  source = "${var.frontend_build_path}/${each.value}"
  content_type = lookup(tomap({ # 一般的なMIMEタイプ
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "jpeg" = "image/jpeg",
    "gif"  = "image/gif",
    "svg"  = "image/svg+xml",
    "ico"  = "image/x-icon",
    "json" = "application/json",
    "txt"  = "text/plain",
    # 他に必要なMIMEタイプがあれば追加
  }), split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream") # デフォルト
  etag = filemd5("${var.frontend_build_path}/${each.value}")                                  # ファイル内容の変更を検知して再アップロード
}

# --- CloudFront Origin Access Control (OAC) ---
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-s3-oac"
  description                       = "OAC for S3 bucket access from CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- S3 Bucket Policy to Allow CloudFront OAC ---
data "aws_iam_policy_document" "s3_bucket_policy_for_cloudfront" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend_bucket.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy_for_cloudfront.json
}


# --- CloudFront Distribution ---
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} CloudFront Distribution"
  default_root_object = "index.html"

  # (オプション) 独自ドメインとACM証明書を使用する場合
  # aliases = [var.domain_name]
  # viewer_certificate {
  #   acm_certificate_arn      = var.acm_certificate_arn_us_east_1 # us-east-1の証明書
  #   ssl_support_method       = "sni-only"
  #   minimum_protocol_version = "TLSv1.2_2021"
  # }

  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id                = "S3-${var.s3_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  origin {                             # API Backend Origin
    domain_name = var.api_alb_dns_name # バックエンドAPIのALB DNS名
    origin_id   = "ALB-${var.project_name}-API"
    custom_origin_config {
      http_port                = 80 # ALBがHTTPでリッスンしている場合
      https_port               = 443
      origin_protocol_policy   = "http-only" # ALBがHTTPのみなら "http-only", HTTPSなら "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}" # デフォルトはS3

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 3600  # 1 hour
    max_ttl                = 86400 # 24 hours

    # (オプション) Cache PolicyやOrigin Request Policyを指定
    # cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    # origin_request_policy_id = "..."
  }

  ordered_cache_behavior { # APIリクエストのルーティング
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]    # OPTIONSもキャッシュするとCORSプリフライトが速くなる
    target_origin_id = "ALB-${var.project_name}-API" # APIオリジンへ

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 0 # APIレスポンスは基本キャッシュしない
    max_ttl                = 0

    # APIリクエストに必要なヘッダー、クッキー、クエリ文字列を転送するポリシー
    # 例: "Managed-AllViewer" またはカスタムポリシー
    # cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    forwarded_values { # CachingDisabled を使わない場合は手動で設定
      query_string = true
      cookies {
        forward = "all" # または "none", "whitelist"
      }
      headers = ["Authorization", "Content-Type", "Origin", "Referer", "User-Agent"] # 必要なヘッダー
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none" # "whitelist" や "blacklist" も可能
      # locations        = []
    }
  }

  # SPA用に403/404エラーをindex.htmlにフォールバック
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # (オプション) ログ設定
  # logging_config {
  #   include_cookies = false
  #   bucket          = "your-cloudfront-logs-s3-bucket.s3.amazonaws.com"
  #   prefix          = "cloudfront-logs/${var.project_name}/"
  # }

  # 変更があった場合に新しいデプロイメントをトリガーするためのダミー値
  # S3オブジェクトが更新されたときにCloudFrontを更新するため（手動キャッシュ無効化の代わり）
  # ただし、これだけでは即時反映されないため、キャッシュ無効化も推奨
  # lifecycle {
  #   replace_triggered_by = [
  #     # 本来はaws_s3_object.frontend_files の map の値をリストに変換して渡したいが、
  #     # 直接はできないので、ダミーとして S3 バケットの ARN の変更をトリガーにするなど工夫が必要
  #     # または、aws_s3_bucket_object リソースを個別に定義してその etag を参照する
  #     aws_s3_bucket.frontend_bucket.arn
  #   ]
  #   ignore_changes = [
  #     # logging_config # ログ設定変更を無視する場合
  #   ]
  # }
}

# (オプション) Route 53で独自ドメインを設定する場合
# resource "aws_route53_record" "www" {
#   count   = var.domain_name != "" && var.hosted_zone_id != "" ? 1 : 0
#   zone_id = var.hosted_zone_id
#   name    = var.domain_name
#   type    = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.main.domain_name
#     zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
#     evaluate_target_health = false
#   }
# }
