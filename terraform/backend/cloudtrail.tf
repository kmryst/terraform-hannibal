# terraform/backend/cloudtrail.tf
# CloudTrail for IAM Policy Analysis

# S3 Bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.project_name}-cloudtrail-logs"

  tags = {
    Name        = "${var.project_name} CloudTrail Logs"
    Environment = "production"
    Purpose     = "IAM Policy Analysis"
  }
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_logs.json
}

data "aws_iam_policy_document" "cloudtrail_logs" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "AWSCloudTrailBucketExistenceCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
  }
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name           = "${var.project_name}-terraform-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.bucket

  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true

  # Management events - すべてのAWSサービスのAPI呼び出しを記録
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Name        = "${var.project_name} Terraform Trail"
    Environment = "production"
    Purpose     = "IAM Policy Analysis"
  }
}

# Access Analyzer
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.project_name}-analyzer"
  type          = "ACCOUNT"

  tags = {
    Name        = "${var.project_name} Access Analyzer"
    Environment = "production"
    Purpose     = "IAM Policy Analysis"
  }
}