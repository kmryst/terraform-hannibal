# terraform/frontend/main.tf

# --- S3 Bucket for Frontend Static Files ---
data "aws_s3_bucket" "frontend_bucket" {
  bucket = var.s3_bucket_name
}

# --- Block Public Access for S3 Bucket ---
# セキュリティ強化のため、S3バケットがインターネットから直接アクセスされるのを防ぐ
resource "aws_s3_bucket_public_access_block" "frontend_bucket_public_access" {
  bucket = data.aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true # バケットやオブジェクトに対するパブリックなACL（アクセス制御リスト）をすべて拒否
  block_public_policy     = true # バケットポリシーによるパブリックアクセス許可もすべて拒否
  ignore_public_acls      = true # 既存のパブリックACLも無視し、強制的に拒否
  restrict_public_buckets = true # バケットがパブリックアクセスを許可する設定になっていても、すべてのパブリックアクセスをブロック
}

# --- Upload Frontend Files to S3 ---
# client/dist ディレクトリ内のファイルをS3バケットにアップロード
# S3オブジェクトとは、AWSのS3バケット内に保存される1つ1つのファイルやデータのことです
resource "aws_s3_object" "frontend_files" {
  for_each = fileset(var.frontend_build_path, "**/*.*") # **/ 任意の階層のサブディレクトリを意味します
  # fileset(path, pattern) path の中から pattern にマッチする path をリストにして返す
  # for_each 同じ種類のリソースを複数作成するための「メタ引数」です。ループ処理のように機能します。each.key, each_value が使えるようになります

  bucket = data.aws_s3_bucket.frontend_bucket.id
  key    = each.value                                 # S3バケット内でのファイルパス
  source = "${var.frontend_build_path}/${each.value}" # アップロード元のローカルファイルパス
  content_type = lookup(tomap({
    # Terraformのマップ(連想配列)をリテラル構文で書くときは {"key"="value"} でくくる
    # tomap() で明示的にマップ型に変換する
    # lookup(マップ, 検索キー, デフォルト値)
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
  }), split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
  etag = filemd5("${var.frontend_build_path}/${each.value}") # terraform apply 時に、変更を検知したファイルのみ自動で再アップロード
  # filemd5 指定したファイルのMD5ハッシュ値を計算する
  # etag: Entity Tag
}


# CloudFrontのみがS3にアクセスできるように設定するための、CloudFront distribution 側の設定
# OACは「CloudFrontからS3バケットへの専用アクセス権限」を管理するAWSの機能です
# Origin は、CloudFrontが配信するコンテンツの「取得元」のことです。S3, ALB/ELBなど
# --- CloudFront Origin Access Control (OAC) ---
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-s3-oac" # AWS上での名前
  description                       = "OAC for S3 bucket access from CloudFront"
  origin_access_control_origin_type = "s3"

  signing_behavior = "always"
  # リクエストにデジタル署名をつけるタイミング
  # "always" すべてのリクエストに常に署名をつける(もっともセキュアな設定)

  signing_protocol = "sigv4"
  # 使用する署名プロトコルの種類
  # AWS Signature Version 4(AWSの最新の認証方式)
}

# # CloudFrontのみがS3にアクセスできるように設定するための、S3 bucket 側の設定 
# --- S3 Bucket Policy to Allow CloudFront OAC ---
data "aws_iam_policy_document" "s3_bucket_policy_for_cloudfront" {
  statement {                                                   # IAMポリシーの「ルール」を定義する
    actions   = ["s3:GetObject"]                                # S3バケットからオブジェクト（ファイル）を取得する操作
    resources = ["${data.aws_s3_bucket.frontend_bucket.arn}/*"] # ${} Terraformの変数展開構文

    principals { # 主体
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {                                         # 条件付きアクセス制御
      test     = "StringEquals"                         # 文字列が完全に一致するかどうかテストする
      variable = "AWS:SourceArn"                        # Source 送信元
      values   = [aws_cloudfront_distribution.main.arn] #比較対象となる値のリスト
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = data.aws_s3_bucket.frontend_bucket.id
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
    domain_name = data.aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    # nestjs-hannibal-3-frontend.s3.ap-northeast-1.amazonaws.com
    # 実際にHTTPリクエストを送信するため、DNS name が必要

    origin_id                = "S3-${var.s3_bucket_name}" # CloudFrontに複数の origin がある場合の識別に使用する
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
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

  ordered_cache_behavior { # APIリクエストのルーティング
    path_pattern    = "/api/*"
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]

    cached_methods = ["GET", "HEAD", "OPTIONS"]
    # GET(データ取得)、HEAD(メタデータ確認)、OPTIONS(同じドメインでも、複雑なリクエストにはCORSチェックが入るため)

    target_origin_id = "ALB-${var.project_name}-API" # APIオリジンへ

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 0 # APIレスポンスは基本キャッシュしない
    max_ttl                = 0



    # AWSが事前に作成したポリシーを使用
    # cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled
    # origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"  # Managed-AllViewer

    # APIリクエストに必要なヘッダー、クッキー、クエリ文字列を転送するポリシー
    forwarded_values { # CachingDisabled を使わない場合は手動で設定 # 転送された値

      query_string = true
      # S3へのリクエストにクエリは不要だが、APIへのリクエストにクエリは必要

      # クライアントから送信されるすべてのHTTPクッキーをオリジンに転送する
      # 認証トークンやセッションIDがクッキーに保存される
      cookies {
        forward = "all" # または "none", "whitelist"
      }

      # - "Authorization": 認証情報を含むヘッダー。API認証などで使用
      # - "Content-Type": リクエストやレスポンスのデータ形式を指定するヘッダー
      # - "Origin": リクエスト元のオリジン（スキーム、ホスト、ポート）を示すヘッダー。CORS制御で利用
      # - "Referer": リクエスト元のページURLを示すヘッダー。リファラ情報の送信に使用
      # - "User-Agent": クライアントのソフトウェア情報（ブラウザやアプリなど）を示すヘッダー
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

  viewer_certificate { # 閲覧者（Viewer）向けの証明書設定
    cloudfront_default_certificate = true
    # 自分で用意した独自ドメインではなく、CloudFrontから提供されるドメイン名でHTTPS通信が有効になります
  }
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
