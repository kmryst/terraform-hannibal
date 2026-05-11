# CloudTrail 監査ログ基盤

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = "nestjs-hannibal-3-cloudtrail-logs"

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
        Resource = "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs"
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
        Resource = "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/AWSLogs/${var.aws_account_id}/*"
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
  s3_bucket_name                = "nestjs-hannibal-3-cloudtrail-logs"
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

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}
