# System Design - NestJS Hannibal 3

## 概要
ハンニバルのアルプス越えルートを可視化するWebアプリケーションのシステム設計書

## アーキテクチャパターン

### 3層アーキテクチャ
- **Presentation Layer**: React + TypeScript フロントエンド
- **Application Layer**: NestJS + GraphQL API
- **Data Layer**: PostgreSQL + 地理データ

### マイクロサービス指向設計
```
Frontend (React) → API Gateway (ALB) → Backend (ECS) → Database (RDS)
                                    ↓
                              Static Assets (S3 + CloudFront)
```

## コンポーネント設計

### フロントエンド（実装済み）
```typescript
client/src/
├── components/          # React コンポーネント
│   ├── Map/            # Mapbox地図コンポーネント
│   └── Route/          # ルート表示コンポーネント
├── apollo/             # Apollo Client設定
├── services/           # API Service層
└── utils/              # ユーティリティ関数
```

### バックエンド（実装済み）
```typescript
src/
├── modules/            # 機能別モジュール
│   ├── route/          # ルート管理（GraphQL Resolver + Service）
│   └── map/            # 地図データ処理
├── entities/           # TypeORM Entity
│   └── route.entity.ts # Route データモデル
├── graphql/            # GraphQL Schema自動生成
├── common/             # 共通機能
│   └── interfaces/     # 型定義（GeoJSON等）
└── main.ts             # アプリケーションエントリーポイント（CORS設定）
```

**実装されていない機能:**
- 認証・認可（Auth0/Cognito）- 将来実装予定
- ガード/インターセプター - 必要に応じて実装予定

## データフロー

### リクエストフロー
1. **ユーザーリクエスト** → CloudFront
2. **静的コンテンツ** → S3から配信
3. **APIリクエスト** → ALB → ECS
4. **データクエリ** → RDS PostgreSQL

### GraphQLスキーマ設計（実装済み）
```graphql
type Route {
  id: ID!
  name: String!
  description: String!
  coordinates: [[Float!]!]!  # JSONB形式の座標配列
  color: String
  createdAt: DateTime!
  updatedAt: DateTime!
}

# GeoJSON形式のクエリも対応
type Query {
  routes: [Route!]!
  route(id: ID!): Route
  hannibalRoute: HannibalRouteCollection!
  pointRoute: PointRouteCollection!
}
```

**データモデルの特徴:**
- **JSONB形式**: 座標データをPostgreSQLのJSONB型で保存
- **GraphQL Code First**: TypeScriptデコレータから自動生成
- **GeoJSON対応**: フロントエンドのMapbox GL JSと連携

## スケーラビリティ設計

### 水平スケーリング（実装済み）
- **ECS Fargate**: 0.25vCPU / 0.5GB メモリ（コスト最適化構成）
- **RDS**: PostgreSQL 15 - t4g.micro（Single-AZ、コスト重視）
- **CloudFront**: グローバルCDN配信

### パフォーマンス最適化（実装済み）
- **GraphQL**: 必要なデータのみ取得（Apollo Client）
- **JSONB型**: PostgreSQLネイティブJSON処理
- **CloudFront キャッシュ**: 静的コンテンツ配信

### 将来実装予定
- **Auto Scaling**: ECS Fargate の自動スケーリング
- **RDS Read Replica**: 読み取り負荷分散
- **Redis キャッシュ**: セッション・クエリキャッシュ
- **DataLoader**: N+1問題解決

## 可用性設計

### Multi-AZ構成
- **ECS**: 複数AZでタスク実行
- **RDS**: Multi-AZ配置
- **ALB**: 複数AZでロードバランシング

### 障害対応
- **ヘルスチェック**: ALB → ECS
- **自動復旧**: ECS Service自動再起動
- **監視**: CloudWatch + アラート

## セキュリティ設計

### ネットワークセキュリティ
- **VPC**: プライベートネットワーク
- **セキュリティグループ**: 最小権限原則
- **WAF**: CloudFront保護（将来実装）

### アプリケーションセキュリティ
- **HTTPS**: 全通信暗号化
- **CORS**: 適切なオリジン制限
- **入力検証**: GraphQL + class-validator

## 運用設計（実装済み）

### CI/CD
- **GitHub Actions**: 3モード対応（Provisioning / Blue-Green / Canary）
- **Blue/Green Deployment**: 約5分で無停止切替
- **Canary Deployment**: 10% → 100% 段階的配信
- **自動ロールバック**: ヘルスチェック失敗時の自動復旧
- **Terraform State管理**: S3 + DynamoDB Lock

### セキュリティ（実装済み）
- **4層防御**: CodeQL (SAST) / Trivy (SCA) / tfsec (IaC) / Gitleaks (Secrets)
- **自動スキャン**: PR作成時 + 週次スケジュール実行
- **GitHub Security統合**: 全結果を一元管理

### 監視・ログ（実装済み）
- **CloudWatch Logs**: ECS タスクログ
- **CloudWatch Metrics**: ECS/RDS/ALB メトリクス
- **Health Check**: ALB → ECS (5回成功で正常判定)
- **CloudTrail**: 全API呼び出しを90日間保持

### 将来実装予定
- **X-Ray**: 分散トレーシング
- **CloudWatch Anomaly Detection**: 異常検知
- **カスタムメトリクス**: ビジネスKPI監視

## 技術的負債管理

### コード品質
- **TypeScript**: 型安全性
- **ESLint/Prettier**: コード規約
- **Jest**: 単体・統合テスト

### 依存関係管理
- **Renovate**: 自動依存関係更新
- **セキュリティスキャン**: 脆弱性検出
- **ライセンス管理**: 適切なライセンス使用

## コスト最適化（実装済み）

### 停止運用による大幅削減
- **通常稼働時**: 月額 $30-50
  - ECS Fargate: 0.25vCPU / 0.5GB ($15-20)
  - RDS t4g.micro ($10-15)
  - ALB ($18)
  - NAT Gateway ($32)
- **停止時**: 月額 $5以下
  - S3 (Terraform State) ($1)
  - CloudTrail ($2)
  - Route53 ($1)
  - 基盤リソース ($1-2)

### 起動/停止の自動化
- **起動**: GitHub Actions (deploy.yml - provisioning モード、約15分)
- **停止**: GitHub Actions (destroy.yml - ワンクリック破棄)

## 将来拡張計画

### 機能拡張
- **ユーザー認証**: Auth0/Cognito導入
- **リアルタイム**: WebSocket対応
- **多言語対応**: i18n実装
- **DataLoader**: N+1問題解決
- **Redis キャッシュ**: セッション・クエリキャッシュ

### インフラ拡張
- **Auto Scaling**: ECS Fargate 自動スケーリング
- **Multi-AZ**: RDS Multi-AZ配置
- **WAF**: CloudFront + ALB 保護
- **GuardDuty**: 脅威検知
- **X-Ray**: 分散トレーシング

---
**最終更新**: 2025年10月12日  
**バージョン**: 2.0（実装済み機能を反映）