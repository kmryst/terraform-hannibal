# Security Design

## セキュリティ概要

PR品質ゲート + 週次/手動セキュリティスキャン + IAM最小権限によるDevSecOps実践

構造化された脅威分析、現状対策、残存リスク、accepted risk の判断理由は [Threat Model](../security/threat-model.md) を参照します。

## 実装済みセキュリティ対策

### 1. PR品質ゲート / セキュリティスキャン

**GitHub Actions: `pr-check.yml` / `security-scan.yml`**

| スキャン種別 | ツール | 対象 | 実行タイミング |
|-------------|--------|------|----------------|
| **Terraform lint** | TFLint | Terraform / AWS provider lint | PR |
| **IaC Security** | Trivy Config | Terraform / Dockerfile 設定ミス | PR（初期導入時は review signal） |
| **Secrets** | Gitleaks | Git履歴の secret 漏洩 | PR |
| **SAST** | CodeQL | ソースコード脆弱性 | 週次/手動実行 |
| **SCA** | Trivy | 依存関係/コンテナ | 週次/手動実行 |

IaC security は `tfsec` を新規採用せず、Aqua Security の `Trivy Config` に寄せる。
品質ゲートの詳細は [docs/operations/quality-gates.md](../operations/quality-gates.md) を参照。

### 2. ネットワークセキュリティ（実装済み）

#### 3層VPCアーキテクチャ

```text
Internet Gateway
    ↓
Public Subnet (ALB) ← CloudFront origin-facing traffic のみ許可
    ↓
App Subnet (ECS) ← NAT Gateway経由でアウトバウンドのみ
    ↓
Data Subnet (RDS) ← 完全非公開（Public IP なし）
```

**特徴:**

- DB層は完全非公開（インターネットアクセス不可）
- ECSはNAT Gateway経由でDockerイメージ取得
- ALB は internet-facing のまま維持するが、CloudFront 経由の API origin 通信だけを通すように制限する
- Public Subnet は ALB / NAT Gateway 用に維持するが、サブネット内のリソースへ Public IP を自動付与しない
- NAT Gateway は明示的に割り当てた Elastic IP を使うため、Public IP 自動付与の無効化による影響はない

### セキュリティグループ

```hcl
# ALB Security Group
data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  ingress {
    from_port       = 80
    to_port         = 8080
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id]
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

#### Public ALB 直アクセス制限

CloudFront の API origin は `api.hamilcar-hannibal.click` を参照し、その DNS は Route53 alias で ALB に向いています。
そのため `aws_lb.main.internal = true` を単純に採用すると、現在の CloudFront custom origin から ALB へ到達できなくなる可能性があります。
internal ALB 化は CloudFront VPC origins を含む private origin 構成への移行として別途設計します。

Issue #232 では、既存の CloudFront 経由公開を維持しながら ALB への直接アクセスを減らすため、次の二段制限を採用します。

- Security Group は AWS managed prefix list `com.amazonaws.global.cloudfront.origin-facing` からの TCP `80-8080` のみ許可する
- CloudFront の ALB origin に `X-Hannibal-Origin-Verify` custom header を追加する
- ALB の 443 / 8080 listener rule は、上記 header の値が一致する場合のみ target group へ forward する
- header が一致しないリクエストは fallback listener rule で `403 Access denied` を返す

CloudFront managed prefix list の weight は 55 で、default security group rule quota に近い値です。
80 / 443 / 8080 を個別 rule にすると quota を超える可能性が高いため、ALB listener 範囲として TCP `80-8080` を1本の rule にまとめます。
未使用ポートは ALB listener が存在しないため application traffic にはなりません。

origin verify header の値は Terraform の `random_password` で生成し、Git には保存しません。
ただし値は Terraform state に保存されるため、state bucket と state 操作用 IAM のアクセス管理を前提にします。
ローテーションする場合は `alb_origin_secret_rotation_version` を `v1` から `v2` などへ更新して `terraform apply` します。

## IAM設計

### 最小権限原則

- **role 分離**: CICDRole（deploy/destroy）/ PRPlanRole（PR plan）/ DeveloperRole（日常開発）/ FoundationRole（foundation apply）を用途ごとに分離
- **write/exec の action 列挙**: 書き込み・実行系は必要な action を明示列挙し、Resource も対象リソースに絞る
- **read 系のプレフィックス wildcard**: `Get*` / `Describe*` / `List*` は意図的な wildcard 設計。AWS が API を追加した際に policy 変更なしで対応できる。read-only のため情報漏洩以外のリスクがない
- **Permission Boundary**: 全 Hannibal 系 Role に専用 Boundary を付与し、最大権限の上限を設定する

## アプリケーションセキュリティ

### コンテナセキュリティ（実装済み）

#### 非 root ユーザー実行

`node:24-alpine` に組み込みの `node` ユーザーで ECS タスクを実行する。Node.js 24 LTSをruntime contractとし、コンテナの脆弱性を突かれた場合のホスト影響を最小化する。

```dockerfile
RUN chmod 644 /opt/rds-ca-2019-root.pem
USER node
CMD ["node", "dist/main.js"]
```

### GraphQL セキュリティ（実装済み）

#### 開発環境限定のGraphiQL / introspectionとCSRF prevention

deprecatedなGraphQL Playgroundは使用しない。`NODE_ENV=production` のときGraphiQLとintrospectionを無効化し、スキーマ情報の外部公開を防ぐ。Apollo ServerのCSRF preventionは全環境で有効にし、frontendの`Content-Type: application/json`を伴うPOSTは許可し、preflight条件を満たさないsimple requestは拒否する。

```typescript
GraphQLModule.forRoot<ApolloDriverConfig>({
  csrfPrevention: true,
  graphiql: process.env.NODE_ENV !== 'production',
  introspection: process.env.NODE_ENV !== 'production',
})
```

### 認証・認可

```typescript
// JWT認証 (将来実装)
**入力検証** (実装済み)
```typescript
// GraphQL + class-validator による自動検証
@InputType()
export class CreateRouteInput {
  @Field()
  @IsString()
  @Length(1, 100)
  name: string;

  @Field(() => [[Float]])
  @IsArray()
  coordinates: number[][];
}
```

**CORS設定** (実装済み)

```typescript
// app.setup.ts
app.enableCors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) callback(null, true);
    else callback(new Error('Not allowed by CORS'));
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
});
```

許可originは完全一致で比較する。将来multipart uploadまたはsimple GETを使うGraphQL clientを追加する場合は、`Apollo-Require-Preflight`とCORS allowlistを同時に更新し、CSRF preventionを無効化して回避しない。

### 3. アプリケーションセキュリティ（将来実装予定）

#### 認証・認可

- JWT/OAuth 2.0 認証（未実装）
- 行レベルセキュリティ（未実装）

```typescript
// 将来実装例
@UseGuards(JwtAuthGuard)
@Resolver(() => Route)
export class RouteResolver {
  @Query(() => [Route])
  async getRoutes(@CurrentUser() user: User): Promise<Route[]> {
    return this.routeService.findByUser(user.id);
  }
}
```

## 4. データセキュリティ（実装済み）

### 暗号化

- **転送時**: HTTPS/TLS 1.3 (CloudFront + ALB)
- **保存時**: RDS暗号化 (AES-256) + S3暗号化
- **機密情報**: AWS Secrets Manager でDB認証情報管理

### データベースセキュリティ (Terraform: `modules/storage/rds/main.tf`)

```hcl
resource "aws_db_instance" "main" {
  storage_encrypted         = true
  backup_retention_period   = 7
  deletion_protection       = true
  publicly_accessible       = false  # 完全非公開
  vpc_security_group_ids    = [aws_security_group.rds.id]
}
```

### 機密情報管理 (実装済み)

```typescript
// TypeORM: DATABASE_URL環境変数から取得
TypeOrmModule.forRootAsync({
  useFactory: () => ({
    type: 'postgres',
    url: process.env.DATABASE_URL,  // Secrets Managerから取得
    entities: [Route],
    synchronize: false,
  }),
})
```

## 5. 監査・コンプライアンス（実装済み）

### CloudTrail設定 (Terraform: `foundation/cloudtrail.tf`)

```hcl
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
}
```

**ログ保存先**: `nestjs-hannibal-3-cloudtrail-logs`（手動作成・永続保持）

### ログ分析 (Athena: 実装済み)

```sql
-- IAM権限使用状況分析
SELECT 
  eventName,
  COUNT(*) as usage_count,
  userIdentity.principalId
FROM cloudtrail_logs 
WHERE eventTime >= date_add('day', -30, current_date)
GROUP BY eventName, userIdentity.principalId
ORDER BY usage_count DESC
LIMIT 20;
```

**分析クエリ保存先**: `docs/operations/README.md`

## 6. 脅威検知・対応

### WAF 無効化の accepted risk

CloudFront / ALB の WAF は、現時点では有効化していません。
この判断は、ポートフォリオ / デモ用途の短時間公開と、通常 destroy 済みで停止しておく運用を前提にした accepted risk です。

**今すぐ有効化しない理由:**

- デモ環境は常時公開ではなく、必要時に起動して確認後に停止する
- WAF を常時有効化すると、停止運用で抑えている固定費が増える
- 公開対象はデモアプリで、DB は private subnet 上にあり、RDS は外部非公開
- PR 時の Trivy Config / Gitleaks、週次/手動の CodeQL / Trivy scan で構成と依存関係の確認は継続する

**再検討条件:**

- デモ環境を継続公開する運用へ変える
- 外部利用者が増え、CloudFront / ALB への不特定アクセスが増える
- 攻撃的なアクセス、bot、異常な 4xx / 5xx の増加を観測する
- 本番相当環境や共有環境として扱う段階に入る

Trivy Config の WAF 検出は、現時点では CI を止める修正対象ではなく、review signal / accepted risk として追跡します。
将来 WAF を有効化する場合は、CloudFront Web ACL を優先候補とし、必要に応じて ALB 側の保護も検討します。

### GuardDuty設定 (コスト最適化のため無効化中)

```hcl
# terraform/foundation/guardduty.tf
resource "aws_guardduty_detector" "hannibal" {
  enable = false  # 月額$30-50のため停止中
}
```

**無効化理由**: ポートフォリオプロジェクトのためコスト優先

### CloudWatch監視 (実装済み)

- **ECS Task Health**: 5分間隔でヘルスチェック
- **ALB Target Health**: Unhealthy時に自動切り離し
- **RDS Connections**: 接続数監視
- **Billing Alarm**: 月額$50超過でSNS通知

## 7. セキュリティテスト（実装済み）

### PR時の自動スキャン

```yaml
# .github/workflows/pr-check.yml
on:
  pull_request:
    branches: [main]
```

### 脆弱性管理

- **Dependency graph**: manifest / lockfile / workflow から依存関係を認識し、Dependabot alerts / security updates の土台として使用
- **Dependabot alerts / vulnerability alerts**: dependency graph と GitHub Advisory Database を照合し、既知脆弱性を通知
- **Dependabot security updates**: alert を解消する最小修正 PR を作成
- **Dependabot version updates**: `.github/dependabot.yml` に従い、脆弱性有無に関係なく依存関係の定期更新 PR を作成
- **GitHub Actions action pin**: GitHub-owned actions は `@vX.Y.Z`、non-GitHub-owned actions は `@<full-length-sha> # vX.Y.Z` で固定する（[ADR 0017](../adr/0017-pin-github-actions-by-owner-tier.md)）
- **TFLint/Trivy Config/Gitleaks**: PRでTerraform lint、IaC security、secret scanを実行
- **CodeQL/Trivy**: 手動のセキュリティスキャンでSAST/SCA/コンテナを確認
- **結果統合**: SARIF対応スキャンはGitHub Securityタブへ集約

## 8. セキュリティ運用（実装済み）

### 定期監査（手動実施）

- **月次**: IAM権限レビュー（Athena分析）
- **四半期**: CloudTrail ログ分析
- **随時**: Dependabot alerts / security update PR 対応

### 実績メトリクス

- **IAM権限最適化**: role 分離・write/exec 列挙・Permission Boundary による最小権限設計を実装済み（#164, #293）
- **PR品質ゲート**: Terraform公式チェックに加え、TFLint / Trivy Config / Gitleaks を自動実行
- **脆弱性修正**: Dependabot alerts / security updates / version updates を用途別に確認し、PR をレビューしてマージ

## セキュリティ成熟度評価

| カテゴリ | 実装状況 | レベル |
|---------|---------|--------|
| **ネットワーク** | 3層VPC + 完全DB非公開 | 🟢 高 |
| **IAM** | Permission Boundary + AssumeRole | 🟢 高 |
| **自動スキャン** | 4層防御 (SAST/SCA/IaC/Secrets) | 🟢 高 |
| **暗号化** | TLS 1.3 + RDS/S3暗号化 | 🟢 高 |
| **監査** | CloudTrail + Athena分析 | 🟡 中 |
| **認証・認可** | 未実装 (将来計画) | 🔴 低 |
| **脅威検知** | GuardDuty停止中 (コスト優先) | 🔴 低 |

**総合評価**: DevSecOps実践レベル（認証機能は将来実装）

---
**最終更新**: 2026年6月4日  
**セキュリティレベル**: ポートフォリオ向けDevSecOps実装  
**実装範囲**: ネットワーク層・インフラ層・CI/CD層のセキュリティ対策完了
