# CloudFrontのみがS3にアクセスできるように設定するための、CloudFront distribution 側の設定
# OACは「CloudFrontからS3バケットへの専用アクセス権限」を管理するAWSの機能です
# Origin は、CloudFrontが配信するコンテンツの「取得元」のことです。S3, ALB/ELBなど
# --- CloudFront Origin Access Control (OAC) ---
data "aws_cloudfront_origin_access_control" "s3_oac" {
  id = "E1EA19Y8SLU52D" # 既存のOACのIDを直接指定
}

# --- CloudFront Distribution ---
# =============================
# ✅ 更新: destroy.ymlでenable_cloudfront=trueを指定することで、
# CloudFrontディストリビューションも自動的に削除されます。
# 手動での事前削除は不要です。
# =============================
resource "aws_cloudfront_distribution" "main" {
  count               = var.enable_cloudfront ? 1 : 0
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} CloudFront Distribution"
  default_root_object = "index.html"

  # 独自ドメインとACM証明書を使用
  aliases = [var.domain_name]

  origin {
    domain_name = var.s3_bucket_regional_domain_name
    # nestjs-hannibal-3-frontend.s3.ap-northeast-1.amazonaws.com
    # 実際にHTTPリクエストを送信するため、DNS name が必要

    origin_id                = "S3-${var.s3_bucket_name}" # CloudFrontに複数の origin がある場合の識別に使用する
    origin_access_control_id = data.aws_cloudfront_origin_access_control.s3_oac.id
  }

  origin { # API Backend Origin

    domain_name = var.api_alb_dns_name
    # バックエンドAPIのALB DNS名
    # 例: api-alb-123456789.ap-northeast-1.elb.amazonaws.com

    origin_id = "ALB-${var.project_name}-API" # CloudFrontに複数の origin がある場合の識別に使用する
    custom_origin_config {
      http_port                = 80 # ALBがHTTPでリッスンしている場合
      https_port               = 443
      origin_protocol_policy   = "http-only" # ALBがHTTPのみなら "http-only", HTTPSなら "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 30 # オリジンからの応答タイムアウト
      origin_keepalive_timeout = 5  # TCP接続の維持時間
    }
  }

  default_cache_behavior {                        # 実質、フロントエンドのキャッシュ設定ｃｃ
    allowed_methods  = ["GET", "HEAD", "OPTIONS"] # CloudFrontが受け付けるHTTPメソッド
    cached_methods   = ["GET", "HEAD"]            # フロントエンドでCORSのプリフライトリクエストはほぼないので、OPTIONS は不要です
    target_origin_id = "S3-${var.s3_bucket_name}" # キャッシュにない場合の取得元オリジンを指定（通常はキャッシュから返す）

    viewer_protocol_policy = "redirect-to-https" # ユーザーがHTTPでアクセスした場合に自動的にHTTPSにリダイレクトする

    compress = true
    # 静的ファイル（JS、CSS、HTMLなど）を自動的に圧縮して配信する機能を有効にしています

    # Time to Live
    # この場合、S3側の設定がないので、3600秒キャッシュされます
    min_ttl     = 0     # 最低限これだけはキャッシュ
    default_ttl = 3600  # 1時間 オリジンが何も指示しない場合の値
    max_ttl     = 86400 # 24時間 これより長くはキャッシュしない

    forwarded_values { # 転送する値 CloudFrontオリジンに転送する値

      query_string = false
      # ユーザーリクエスト:https://example.com/main.js?version=1.0
      # CloudFront → S3: GET /main.js (クエリ ?version=1.0 は送らない)
      # 静的ファイル（HTML、JS、CSS、画像）の配信では、通常クエリパラメータに関係なく同じファイルを返すため、クエリパラメータを無視することでキャッシュ効率が向上します

      # Reactアプリの静的ファイル配信では、通常クッキーによってコンテンツが変わることはないため、クッキーを無視することでキャッシュのヒット率が大幅に向上し、ページの読み込み速度が高速化されます
      cookies {
        forward = "none"
      }
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "ALB-${var.project_name}-API"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
      headers = ["Authorization", "Content-Type", "Origin", "Referer", "User-Agent"]
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/graphql"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "ALB-${var.project_name}-API"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
      headers = ["Authorization", "Content-Type", "Origin", "Referer", "User-Agent"]
    }
  }

  restrictions { # 制限
    geo_restriction {
      restriction_type = "whitelist" # "none" や "blacklist" も可能
      locations        = ["JP"]      # 日本からのみアクセス可能
    }
  }

  # SPA(Single Page Application)用に403/404エラーをindex.htmlにフォールバック
  custom_error_response {
    error_code         = 403 # 403 アクセス禁止
    response_code      = 200 # 200 正常な応答
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404 # 404 Not Found
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

  viewer_certificate {                                      # 閲覧者（Viewer）向けの証明書設定
    acm_certificate_arn = var.acm_certificate_arn_us_east_1 # us-east-1の証明書
    ssl_support_method  = "sni-only"
    # SNI（Server Name Indication）: 1つのIPアドレスで複数のSSL証明書を使い分ける技術
    minimum_protocol_version = "TLSv1.2_2021"
  }
}