# データフロー & 監査

## 📊 データフロー構成

```mermaid
graph TB
    %% Application Flow
    subgraph "🔄 Application Data Flow"
        Client[React Client<br/>TypeScript + GraphQL]
        API[NestJS API<br/>GraphQL + REST]
        DB[PostgreSQL<br/>Route Data]
        
        Client <--> |GraphQL Queries| API
        API <--> |SQL| DB
    end
    
    %% Monitoring Flow
    subgraph "📊 Monitoring & Audit Flow"
        CloudTrail[CloudTrail<br/>API Call Logs]
        S3_Logs[S3 Bucket<br/>nestjs-hannibal-3-cloudtrail-logs]
        Athena_DB[Athena Database<br/>hannibal_cloudtrail_db]
        Analysis[Permission Analysis<br/>76/160 Permissions Used]
        
        CloudTrail --> S3_Logs
        S3_Logs --> Athena_DB
        Athena_DB --> Analysis
    end
    
    %% CI/CD Data Flow
    subgraph "🚀 CI/CD Data Flow"
        GitHub_Code[GitHub Repository<br/>Source Code]
        Docker_Build[Docker Build<br/>Multi-stage]
        ECR_Push[ECR Push<br/>Container Image]
        ECS_Deploy[ECS Deploy<br/>Blue/Green]
        
        GitHub_Code --> Docker_Build
        Docker_Build --> ECR_Push
        ECR_Push --> ECS_Deploy
    end
    
    %% Connections
    API -.-> |Logs| CloudTrail
    ECS_Deploy -.-> |Updates| API
    
    %% Styling
    classDef app fill:#e3f2fd
    classDef monitor fill:#f3e5f5
    classDef cicd fill:#e8f5e8
    
    class Client,API,DB app
    class CloudTrail,S3_Logs,Athena_DB,Analysis monitor
    class GitHub_Code,Docker_Build,ECR_Push,ECS_Deploy cicd
```

## 🔍 監査・分析システム

### CloudTrail設定

```json
{
  "TrailName": "nestjs-hannibal-3-cloudtrail",
  "S3BucketName": "nestjs-hannibal-3-cloudtrail-logs",
  "IncludeGlobalServiceEvents": true,
  "IsMultiRegionTrail": true,
  "EnableLogFileValidation": true
}
```

### Athena分析クエリ

```sql
-- CI/CD権限使用状況分析
SELECT 
  CONCAT(
    regexp_replace(record.eventSource, '\.amazonaws\.com$', ''), 
    ':', 
    record.eventName
  ) as permission,
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
```

## 📈 データ処理パフォーマンス

### GraphQL最適化

- **DataLoader**: N+1問題の解決
- **Query Complexity**: 複雑なクエリの制限
- **Caching**: Redis活用（将来実装）

### データベース設計

```sql
-- ルートデータテーブル
CREATE TABLE routes (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  geojson JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- インデックス最適化
CREATE INDEX idx_routes_geojson ON routes USING GIN (geojson);
```

### 監査ログ保持ポリシー

- **CloudTrail**: 永続保存（コンプライアンス要件）
- **CloudWatch Logs**: 30日間保持
- **Athena結果**: 分析用に1年間保持

## 🚀 CI/CDパイプライン詳細

### GitHub Actions ワークフロー

1. **PR gate (`pr-check.yml`)**: backend/frontend の build・unit test、Docker build、Terraform check、secret scan を merge 前に確認
2. **Deploy (`deploy.yml`)**: PR gate 通過済みの `main` を手動実行し、Terraform apply、frontend build、ECR push、CodeDeploy を実行
3. **Security scan (`security-scan.yml`)**: CodeQL、Trivy dependency/container scan を週次/手動実行

### デプロイメント戦略

- **初期構築**: `provisioning`
- **通常デプロイ**: `bluegreen` または `canary`
- **ロールバック**: CodeDeploy のヘルスチェック失敗時に自動 rollback

## 📊 メトリクス・監視

### アプリケーションメトリクス

- **レスポンス時間**: 平均 < 200ms
- **エラー率**: < 0.1%
- **スループット**: 1000 req/min

### インフラメトリクス

- **CPU使用率**: < 70%
- **メモリ使用率**: < 80%
- **ディスク使用率**: < 85%
