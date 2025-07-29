# Athena分析基盤 - AWS Certified Professional/Specialty設計
# Netflix/Airbnb/Spotify企業レベル品質

# 専用ワークグループ（企業レベル設定）
resource "aws_athena_workgroup" "hannibal_analysis" {
  name = "hannibal-cloudtrail-analysis"
  
  configuration {
    result_configuration {
      output_location = "s3://nestjs-hannibal-3-athena-results/"
      
      # 企業レベル暗号化設定
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
    
    # コスト管理・ガバナンス
    bytes_scanned_cutoff_per_query     = 1073741824  # 1GB制限
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
  bucket = "nestjs-hannibal-3-athena-results"
  
  # 永続化設定
  lifecycle {
    prevent_destroy = true
  }
}

# パーティション対応CloudTrailテーブル（企業レベル設計）
resource "aws_athena_named_query" "create_partitioned_table" {
  name      = "create-partitioned-cloudtrail-table"
  database  = aws_athena_database.hannibal_logs.name
  workgroup = aws_athena_workgroup.hannibal_analysis.name
  
  query = <<EOF
CREATE EXTERNAL TABLE IF NOT EXISTS hannibal_cloudtrail_db.cloudtrail_logs_partitioned (
  Records array<struct<
    eventName:string,
    eventSource:string,
    userIdentity:struct<arn:string,type:string>,
    eventTime:string,
    errorCode:string,
    errorMessage:string,
    sourceIPAddress:string,
    userAgent:string
  >>
)
PARTITIONED BY (
  year string,
  month string,
  day string
)
STORED AS PARQUET
LOCATION 's3://nestjs-hannibal-3-cloudtrail-logs/AWSLogs/258632448142/CloudTrail/ap-northeast-1/'
TBLPROPERTIES (
  'projection.enabled'='true',
  'projection.year.type'='integer',
  'projection.year.range'='2025,2030',
  'projection.month.type'='integer', 
  'projection.month.range'='01,12',
  'projection.day.type'='integer',
  'projection.day.range'='01,31',
  'storage.location.template'='s3://nestjs-hannibal-3-cloudtrail-logs/AWSLogs/258632448142/CloudTrail/ap-northeast-1/$${year}/$${month}/$${day}/',
  'parquet.compress'='SNAPPY'
)
EOF

  description = "パーティション対応CloudTrailテーブル作成（企業レベル設計）"
}

# 権限分析クエリ（動的日付対応）
resource "aws_athena_named_query" "analyze_cicd_permissions" {
  name      = "analyze-hannibal-cicd-permissions"
  database  = aws_athena_database.hannibal_logs.name
  workgroup = aws_athena_workgroup.hannibal_analysis.name
  
  query = <<EOF
SELECT 
  CONCAT(regexp_replace(record.eventSource, '\.amazonaws\.com$', ''), ':', record.eventName) as permission,
  COUNT(*) as usage_count,
  MIN(record.eventTime) as first_used,
  MAX(record.eventTime) as last_used
FROM hannibal_cloudtrail_db.cloudtrail_logs_partitioned
CROSS JOIN UNNEST(Records) AS t(record)
WHERE record.userIdentity.arn LIKE '%HannibalCICDRole-Dev%'
  AND record.errorCode IS NULL
  AND year = '2025' AND month = '07' AND day >= '27'
GROUP BY record.eventSource, record.eventName
ORDER BY usage_count DESC
EOF

  description = "hannibal-cicd権限分析（パーティション最適化・企業レベル）"
}

# 権限総数確認クエリ（企業レベル分析）
resource "aws_athena_named_query" "count_cicd_permissions" {
  name      = "count-hannibal-cicd-permissions"
  database  = aws_athena_database.hannibal_logs.name
  workgroup = aws_athena_workgroup.hannibal_analysis.name
  
  query = <<EOF
SELECT 
  COUNT(DISTINCT CONCAT(regexp_replace(record.eventSource, '\.amazonaws\.com$', ''), ':', record.eventName)) as total_permissions,
  COUNT(*) as total_api_calls,
  COUNT(DISTINCT record.eventSource) as services_used,
  MIN(record.eventTime) as analysis_start,
  MAX(record.eventTime) as analysis_end
FROM hannibal_cloudtrail_db.cloudtrail_logs_partitioned
CROSS JOIN UNNEST(Records) AS t(record)
WHERE record.userIdentity.arn LIKE '%HannibalCICDRole-Dev%'
  AND record.errorCode IS NULL
  AND year = '2025' AND month = '07' AND day >= '27'
EOF

  description = "hannibal-cicd権限統計（企業レベル分析・パーティション最適化）"
}

# エラー分析クエリ（企業レベル監査）
resource "aws_athena_named_query" "analyze_cicd_errors" {
  name      = "analyze-hannibal-cicd-errors"
  database  = aws_athena_database.hannibal_logs.name
  workgroup = aws_athena_workgroup.hannibal_analysis.name
  
  query = <<EOF
SELECT 
  record.errorCode,
  record.errorMessage,
  CONCAT(regexp_replace(record.eventSource, '\.amazonaws\.com$', ''), ':', record.eventName) as failed_permission,
  COUNT(*) as error_count,
  record.sourceIPAddress,
  record.userAgent
FROM hannibal_cloudtrail_db.cloudtrail_logs_partitioned
CROSS JOIN UNNEST(Records) AS t(record)
WHERE record.userIdentity.arn LIKE '%HannibalCICDRole-Dev%'
  AND record.errorCode IS NOT NULL
  AND year = '2025' AND month = '07' AND day >= '27'
GROUP BY record.errorCode, record.errorMessage, record.eventSource, record.eventName, record.sourceIPAddress, record.userAgent
ORDER BY error_count DESC
EOF

  description = "hannibal-cicdエラー分析（セキュリティ監査・企業レベル）"
}