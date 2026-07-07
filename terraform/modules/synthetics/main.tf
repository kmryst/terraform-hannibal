# CloudWatch Synthetics canary for user-journey-level black-box monitoring (ADR-0030).
# env側リソースとしてservice root moduleから呼び出し、deploy.yml/destroy.ymlのライフサイクルと生死を共にする。

data "aws_caller_identity" "current" {}

# --- S3 bucket for canary artifacts (screenshots, HAR files, logs) ---
resource "aws_s3_bucket" "canary_artifacts" {
  bucket        = "${var.project_name}-synthetics-canary-artifacts"
  force_destroy = true

  tags = merge(
    {
      Name = "${var.project_name}-synthetics-canary-artifacts"
    },
    var.tags,
  )
}

resource "aws_s3_bucket_public_access_block" "canary_artifacts" {
  bucket = aws_s3_bucket.canary_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "canary_artifacts" {
  bucket = aws_s3_bucket.canary_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Canary execution role (least privilege) ---
resource "aws_iam_role" "canary_execution" {
  name = "${var.project_name}-synthetics-canary-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# 参照: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries_CanaryPermissions.html
# 「Basic canary that doesn't use AWS KMS or need Amazon VPC access」の権限セットを基本とし、
# GetSecretValueをorigin-verifyヘッダー用secretのARNのみに限定して追加する(最小権限、Issue #465)。
resource "aws_iam_role_policy" "canary_execution" {
  name = "${var.project_name}-synthetics-canary-policy"
  role = aws_iam_role.canary_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = ["${aws_s3_bucket.canary_artifacts.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation"
        ]
        Resource = [aws_s3_bucket.canary_artifacts.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/cwsyn-${var.canary_name}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "xray:PutTraceSegments"
        ]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Resource = "*"
        Action   = "cloudwatch:PutMetricData"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "CloudWatchSynthetics"
          }
        }
      },
      {
        # 最小権限: origin-verifyヘッダー用secretのARNのみに限定する(ワイルドカードで全secretを許可しない)
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [var.origin_verify_secret_arn]
      }
    ]
  })
}

# --- Canary source code (zip) ---
data "archive_file" "canary_zip" {
  type        = "zip"
  source_dir  = "${path.module}/canary-src"
  output_path = "${path.module}/.artifacts/apiCanary.zip"
}

# --- Synthetics canary ---
resource "aws_synthetics_canary" "user_journey" {
  name                 = var.canary_name
  artifact_s3_location = "s3://${aws_s3_bucket.canary_artifacts.bucket}/canary-runs/"
  execution_role_arn   = aws_iam_role.canary_execution.arn
  handler              = "apiCanary.handler"
  zip_file             = data.archive_file.canary_zip.output_path
  runtime_version      = var.runtime_version

  schedule {
    expression = var.schedule_expression
  }

  run_config {
    timeout_in_seconds = var.canary_timeout_in_seconds
    environment_variables = {
      FRONTEND_URL              = var.frontend_url
      API_HEALTH_URL            = var.api_health_url
      API_GRAPHQL_URL           = var.api_graphql_url
      ORIGIN_VERIFY_HEADER_NAME = var.origin_verify_header_name
      ORIGIN_VERIFY_SECRET_ARN  = var.origin_verify_secret_arn
      GRAPHQL_QUERY             = var.graphql_query
    }
  }

  start_canary = true

  tags = merge(
    {
      Name = var.canary_name
    },
    var.tags,
  )

  depends_on = [
    aws_iam_role_policy.canary_execution
  ]
}
