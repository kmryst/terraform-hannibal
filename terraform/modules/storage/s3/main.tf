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

# CloudFrontのみがS3にアクセスできるように設定するための、S3 bucket 側の設定 
# --- S3 Bucket Policy to Allow CloudFront OAC ---
data "aws_iam_policy_document" "s3_bucket_policy_for_cloudfront" {
  statement {                                                   # IAMポリシーの「ルール」を定義する
    actions   = ["s3:GetObject"]                                # S3バケットからオブジェクト（ファイル）を取得する操作
    resources = ["${data.aws_s3_bucket.frontend_bucket.arn}/*"] # ${} Terraformの変数展開構文

    principals { # 主体
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = var.cloudfront_distribution_arn != "" ? [var.cloudfront_distribution_arn] : []
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = data.aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy_for_cloudfront.json
  
  depends_on = [var.cloudfront_distribution_arn]
}