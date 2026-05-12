# CloudTrail 監査ログ基盤

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "nestjs-hannibal-3-cloudtrail-logs"

  tags = {
    Name        = "nestjs-hannibal-3 CloudTrail Logs"
    Environment = "production"
    Purpose     = "IAM Policy Analysis"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.bucket

  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.bucket

  rule {
    id     = "expire-cloudtrail-logs-after-90-days"
    status = "Enabled"

    filter {
      prefix = "AWSLogs/"
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs.bucket}"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:ap-northeast-1:${var.aws_account_id}:trail/nestjs-hannibal-3"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs.bucket}/AWSLogs/${var.aws_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cloudtrail:ap-northeast-1:${var.aws_account_id}:trail/nestjs-hannibal-3"
          }
        }
      }
    ]
  })

  depends_on = [aws_iam_policy.hannibal_foundation_services_policy]
}

resource "aws_cloudtrail" "hannibal_trail" {
  name                          = "nestjs-hannibal-3"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.bucket
  cloud_watch_logs_group_arn    = "${local.cloudtrail_cloudwatch_log_group_arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch_logs_role.arn
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Project     = "nestjs-hannibal-3"
    Environment = "Dev"
    ManagedBy   = "terraform/foundation"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    aws_iam_policy.hannibal_foundation_policy,
    aws_iam_policy.hannibal_foundation_services_policy,
    aws_iam_role_policy.cloudtrail_cloudwatch_logs_policy,
    aws_cloudwatch_log_group.cloudtrail,
    aws_s3_bucket_policy.cloudtrail_logs
  ]
}
