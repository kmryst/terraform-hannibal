# Athena分析基盤 - CloudTrailログ分析用

resource "aws_s3_bucket" "athena_results" {
  bucket = "nestjs-hannibal-3-athena-results"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.bucket

  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 専用ワークグループ（企業レベル設定）
resource "aws_athena_workgroup" "hannibal_analysis" {
  name = "hannibal-cloudtrail-analysis"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"

      # 企業レベル暗号化設定
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    # コスト管理・ガバナンス
    bytes_scanned_cutoff_per_query     = 1073741824 # 1GB制限
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
  }

  # 永続化設定
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project     = "nestjs-hannibal-3"
    Purpose     = "CloudTrail権限分析"
    Environment = "Dev"
    Compliance  = "Professional"
  }
}

# 専用データベース
resource "aws_athena_database" "hannibal_logs" {
  name   = "hannibal_cloudtrail_db"
  bucket = aws_s3_bucket.athena_results.bucket

  # 永続化設定
  lifecycle {
    prevent_destroy = true
  }
}

# パーティション対応CloudTrailテーブル
# CloudTrailInputFormat + JsonSerDe を使用。生の CloudTrail ログ（.json.gz）を直接読み取る。
# PARQUET は Glue ETL 変換後に使う形式であり、生ログには使用できない。
resource "aws_athena_named_query" "create_partitioned_table" {
  name      = "create-partitioned-cloudtrail-table"
  database  = aws_athena_database.hannibal_logs.name
  workgroup = aws_athena_workgroup.hannibal_analysis.name

  query = <<EOF
CREATE EXTERNAL TABLE IF NOT EXISTS hannibal_cloudtrail_db.cloudtrail_logs_partitioned (
  eventVersion       STRING,
  userIdentity       STRUCT<
    type:            STRING,
    principalId:     STRING,
    arn:             STRING,
    accountId:       STRING,
    invokedBy:       STRING,
    accessKeyId:     STRING,
    userName:        STRING,
    sessionContext:  STRUCT<
      attributes:    STRUCT<
        mfaAuthenticated: STRING,
        creationDate:     STRING
      >,
      sessionIssuer: STRUCT<
        type:        STRING,
        principalId: STRING,
        arn:         STRING,
        accountId:   STRING,
        userName:    STRING
      >
    >
  >,
  eventTime          STRING,
  eventSource        STRING,
  eventName          STRING,
  awsRegion          STRING,
  sourceIPAddress    STRING,
  userAgent          STRING,
  errorCode          STRING,
  errorMessage       STRING,
  requestParameters  STRING,
  responseElements   STRING,
  requestId          STRING,
  eventId            STRING,
  eventType          STRING,
  readOnly           STRING,
  recipientAccountId STRING
)
PARTITIONED BY (
  year  STRING,
  month STRING,
  day   STRING
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES (
  'serialization.format' = '1'
)
STORED AS INPUTFORMAT  'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
           OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://nestjs-hannibal-3-cloudtrail-logs/AWSLogs/${var.aws_account_id}/CloudTrail/ap-northeast-1/'
TBLPROPERTIES (
  'projection.enabled'='true',
  'projection.year.type'='integer',
  'projection.year.range'='2025,2030',
  'projection.month.type'='integer',
  'projection.month.range'='01,12',
  'projection.month.digits'='2',
  'projection.day.type'='integer',
  'projection.day.range'='01,31',
  'projection.day.digits'='2',
  'storage.location.template'='s3://nestjs-hannibal-3-cloudtrail-logs/AWSLogs/${var.aws_account_id}/CloudTrail/ap-northeast-1/$${year}/$${month}/$${day}/'
)
EOF

  description = "パーティション対応CloudTrailテーブル作成（CloudTrailInputFormat / JsonSerDe）"
}

# 権限分析クエリ
resource "aws_athena_named_query" "analyze_cicd_permissions" {
  name      = "analyze-hannibal-cicd-permissions"
  database  = aws_athena_database.hannibal_logs.name
  workgroup = aws_athena_workgroup.hannibal_analysis.name

  query = <<EOF
SELECT
  CONCAT(regexp_replace(eventsource, '\.amazonaws\.com$', ''), ':', eventname) AS permission,
  COUNT(*)       AS usage_count,
  MIN(eventtime) AS first_used,
  MAX(eventtime) AS last_used
FROM hannibal_cloudtrail_db.cloudtrail_logs_partitioned
WHERE useridentity.arn LIKE '%HannibalCICDRole-Dev%'
  AND errorcode IS NULL
  AND year = '2025' AND month = '07' AND day >= '27'
GROUP BY eventsource, eventname
ORDER BY usage_count DESC
EOF

  description = "HannibalCICDRole の使用権限一覧（CloudTrailInputFormat 対応）"
}

# 権限総数確認クエリ
resource "aws_athena_named_query" "count_cicd_permissions" {
  name      = "count-hannibal-cicd-permissions"
  database  = aws_athena_database.hannibal_logs.name
  workgroup = aws_athena_workgroup.hannibal_analysis.name

  query = <<EOF
SELECT
  COUNT(DISTINCT CONCAT(regexp_replace(eventsource, '\.amazonaws\.com$', ''), ':', eventname)) AS total_permissions,
  COUNT(*)                    AS total_api_calls,
  COUNT(DISTINCT eventsource) AS services_used,
  MIN(eventtime)              AS analysis_start,
  MAX(eventtime)              AS analysis_end
FROM hannibal_cloudtrail_db.cloudtrail_logs_partitioned
WHERE useridentity.arn LIKE '%HannibalCICDRole-Dev%'
  AND errorcode IS NULL
  AND year = '2025' AND month = '07' AND day >= '27'
EOF

  description = "HannibalCICDRole の権限使用統計（CloudTrailInputFormat 対応）"
}

# エラー分析クエリ
resource "aws_athena_named_query" "analyze_cicd_errors" {
  name      = "analyze-hannibal-cicd-errors"
  database  = aws_athena_database.hannibal_logs.name
  workgroup = aws_athena_workgroup.hannibal_analysis.name

  query = <<EOF
SELECT
  errorcode,
  errormessage,
  CONCAT(regexp_replace(eventsource, '\.amazonaws\.com$', ''), ':', eventname) AS failed_permission,
  COUNT(*) AS error_count,
  sourceipaddress,
  useragent
FROM hannibal_cloudtrail_db.cloudtrail_logs_partitioned
WHERE useridentity.arn LIKE '%HannibalCICDRole-Dev%'
  AND errorcode IS NOT NULL
  AND year = '2025' AND month = '07' AND day >= '27'
GROUP BY errorcode, errormessage, eventsource, eventname, sourceipaddress, useragent
ORDER BY error_count DESC
EOF

  description = "HannibalCICDRole のエラー分析（CloudTrailInputFormat 対応）"
}
