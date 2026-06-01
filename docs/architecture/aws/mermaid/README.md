# アーキテクチャ

## 📋 ドキュメント一覧

- [system-overview.md](./system-overview.md) - 全体システム構成
- [blue-green-deployment.md](./blue-green-deployment.md) - Blue/Green デプロイメント
- [iam-architecture.md](./iam-architecture.md) - IAM権限構成
- [data-flow.md](./data-flow.md) - データフロー & 監査
- [architecture.md](./architecture.md) - システム構成図

## 🏗️ アーキテクチャ原則

### Infrastructure as Code
- Terraformによる完全なインフラ管理
- 環境間の一貫性確保
- 変更履歴の追跡可能性

### セキュリティファースト
- 最小権限の原則
- Permission Boundaryによる制限
- CloudTrail監査ログ

### 無停止デプロイメント
- CodeDeploy Blue/Green Deployment
- ヘルスチェックによる自動切り替え
- ロールバック機能

### 監査性・トレーサビリティ
- 全API呼び出しの記録
- 権限使用状況の分析
- CloudTrail + Athena分析