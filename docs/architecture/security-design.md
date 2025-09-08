# Security Design - NestJS Hannibal 3

## セキュリティ概要
多層防御によるエンタープライズレベルのセキュリティ設計

## ネットワークセキュリティ

### VPC設計
```
Internet Gateway
    ↓
Public Subnet (ALB)
    ↓
Private Subnet (ECS)
    ↓
Private Subnet (RDS)
```

### セキュリティグループ
```hcl
# ALB Security Group
resource "aws_security_group" "alb" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Security Group
resource "aws_security_group" "ecs" {
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}
```

## IAM設計

### 最小権限原則
- **環境別ロール分離**: Dev/Staging/Prod
- **AssumeRole**: クロスアカウント権限委譲
- **Permission Boundary**: 権限上限設定

### 実装済み権限分析
```
総権限数: 160
使用権限: 76 (47.5%)
未使用権限: 84 (52.5%)
```

### 権限最適化計画
1. **Phase 1**: 未使用権限の削除 (84権限)
2. **Phase 2**: 条件付きアクセス導入
3. **Phase 3**: 時限権限の実装

## アプリケーションセキュリティ

### 認証・認可
```typescript
// JWT認証 (将来実装)
@UseGuards(JwtAuthGuard)
@Resolver(() => Route)
export class RouteResolver {
  @Query(() => [Route])
  async getRoutes(@CurrentUser() user: User): Promise<Route[]> {
    return this.routeService.findByUser(user.id);
  }
}
```

### 入力検証
```typescript
// GraphQL + class-validator
@InputType()
export class CreateRouteInput {
  @Field()
  @IsString()
  @Length(1, 100)
  name: string;

  @Field(() => [CoordinateInput])
  @ValidateNested({ each: true })
  @Type(() => CoordinateInput)
  coordinates: CoordinateInput[];
}
```

### CORS設定
```typescript
app.enableCors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
});
```

## データセキュリティ

### 暗号化
- **転送時**: HTTPS/TLS 1.3
- **保存時**: RDS暗号化 + S3暗号化
- **メモリ内**: 機密データの即座削除

### データベースセキュリティ
```sql
-- RDS設定
encrypted = true
backup_retention_period = 7
deletion_protection = true
publicly_accessible = false
```

### 機密情報管理
```typescript
// AWS Secrets Manager
const dbPassword = await this.secretsManager
  .getSecretValue({ SecretId: 'hannibal/db/password' })
  .promise();
```

## 監査・コンプライアンス

### CloudTrail設定
```hcl
resource "aws_cloudtrail" "hannibal" {
  name           = "nestjs-hannibal-3-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail.bucket
  
  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.app.arn}/*"]
    }
  }
}
```

### ログ分析 (Athena)
```sql
-- 権限使用状況分析
SELECT 
  eventName,
  COUNT(*) as usage_count,
  userIdentity.type as user_type
FROM cloudtrail_logs 
WHERE eventTime >= '2024-01-01'
GROUP BY eventName, userIdentity.type
ORDER BY usage_count DESC;
```

## 脅威検知・対応

### GuardDuty設定
```hcl
resource "aws_guardduty_detector" "hannibal" {
  enable = true
  
  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }
}
```

### インシデント対応
1. **検知**: CloudWatch Alarms + SNS
2. **分析**: CloudTrail + GuardDuty
3. **対応**: 自動ブロック + 手動調査
4. **復旧**: バックアップからの復元

## セキュリティテスト

### 自動スキャン
```yaml
# GitHub Actions
- name: Security Scan
  uses: github/super-linter@v4
  env:
    DEFAULT_BRANCH: main
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    VALIDATE_TYPESCRIPT_ES: true
    VALIDATE_DOCKERFILE: true
```

### 脆弱性管理
- **Dependabot**: 依存関係の脆弱性検出
- **Snyk**: コード・コンテナスキャン
- **OWASP ZAP**: 動的セキュリティテスト

## セキュリティ運用

### 定期監査
- **月次**: IAM権限レビュー
- **四半期**: セキュリティ設定監査
- **年次**: ペネトレーションテスト

### セキュリティメトリクス
```
- 未使用IAM権限数: 84 → 0 (目標)
- セキュリティアラート対応時間: < 15分
- 脆弱性修正時間: < 24時間
- セキュリティテストカバレッジ: > 80%
```

---
**更新日**: 2025年1月8日  
**セキュリティレベル**: Enterprise Grade