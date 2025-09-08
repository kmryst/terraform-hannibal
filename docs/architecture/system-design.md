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

### フロントエンド
```typescript
src/
├── components/          # 再利用可能コンポーネント
│   ├── Map/            # Mapbox地図コンポーネント
│   ├── Route/          # ルート表示コンポーネント
│   └── UI/             # 共通UIコンポーネント
├── pages/              # ページコンポーネント
├── hooks/              # カスタムフック
├── graphql/            # GraphQLクエリ・ミューテーション
└── utils/              # ユーティリティ関数
```

### バックエンド
```typescript
src/
├── modules/            # 機能別モジュール
│   ├── route/          # ルート管理
│   ├── geography/      # 地理データ処理
│   └── auth/           # 認証・認可
├── common/             # 共通機能
│   ├── guards/         # ガード
│   ├── interceptors/   # インターセプター
│   └── decorators/     # デコレーター
└── database/           # データベース設定
```

## データフロー

### リクエストフロー
1. **ユーザーリクエスト** → CloudFront
2. **静的コンテンツ** → S3から配信
3. **APIリクエスト** → ALB → ECS
4. **データクエリ** → RDS PostgreSQL

### GraphQLスキーマ設計
```graphql
type Route {
  id: ID!
  name: String!
  coordinates: [Coordinate!]!
  difficulty: Difficulty!
  historicalContext: String
}

type Coordinate {
  latitude: Float!
  longitude: Float!
  elevation: Float
}

enum Difficulty {
  EASY
  MODERATE
  DIFFICULT
  EXTREME
}
```

## スケーラビリティ設計

### 水平スケーリング
- **ECS Fargate**: CPU/メモリ使用率に基づく自動スケーリング
- **RDS**: Read Replica対応（将来拡張）
- **CloudFront**: グローバルCDN配信

### パフォーマンス最適化
- **GraphQL**: 必要なデータのみ取得
- **データローダー**: N+1問題解決
- **キャッシュ戦略**: Redis導入予定

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

## 運用設計

### CI/CD
- **GitHub Actions**: 自動デプロイ
- **Blue/Green**: 無停止デプロイ
- **ロールバック**: 自動・手動対応

### 監視・ログ
- **CloudWatch**: メトリクス・ログ
- **X-Ray**: 分散トレーシング（将来実装）
- **アラート**: 異常検知・通知

## 技術的負債管理

### コード品質
- **TypeScript**: 型安全性
- **ESLint/Prettier**: コード規約
- **Jest**: 単体・統合テスト

### 依存関係管理
- **Renovate**: 自動依存関係更新
- **セキュリティスキャン**: 脆弱性検出
- **ライセンス管理**: 適切なライセンス使用

## 将来拡張計画

### 機能拡張
- **ユーザー認証**: Auth0/Cognito導入
- **リアルタイム**: WebSocket対応
- **多言語対応**: i18n実装

### インフラ拡張
- **CDK移行**: Terraform → AWS CDK
- **コンテナ最適化**: Distroless Image
- **サーバーレス**: Lambda Edge活用

---
**更新日**: 2025年1月8日  
**バージョン**: 1.0