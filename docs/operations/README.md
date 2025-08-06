# 運用ガイド

## 📋 運用ドキュメント一覧

- [iam-management.md](./iam-management.md) - IAM権限管理・Professional設計
- [monitoring.md](./monitoring.md) - 監視・権限分析・CloudTrail

## 🏗️ 運用原則

### AWS Professional設計
- **基盤とアプリケーションの分離**: IAMユーザー・基本ロールは永続化、アプリケーションリソースはTerraform管理
- **環境分離**: 理想は複数AWSアカウント、現実的には環境別ユーザー + ロール分離
- **最小権限原則**: CloudTrail分析による実際の使用権限（76個）に基づく最適化

### Infrastructure as Code
- **手動作業の最小化**: 基盤リソース以外はTerraformで管理
- **再現可能な設計**: 環境間の一貫性確保
- **バージョン管理による変更追跡**: 全変更をGitで管理

### 監査性・トレーサビリティ
- **全操作をCloudTrailで追跡可能**: API呼び出しの完全な記録
- **環境別・機能別の責任分離**: ロールベースのアクセス制御
- **AssumeRoleによる権限使用履歴**: 権限使用の透明性確保

## 🔐 セキュリティ運用

### Permission Boundary
- **最大権限の制限**: 意図しない権限昇格を防止
- **CI/CD境界**: HannibalCICDBoundary
- **ECS境界**: HannibalECSBoundary

### 権限最適化プロセス
1. **CloudTrail収集**: 全API呼び出しを記録
2. **Athena分析**: 実際の権限使用パターンを分析
3. **最小権限適用**: 使用されていない権限を削除
4. **継続的監視**: 定期的な権限見直し

## 🚀 デプロイメント運用

### Blue/Green Deployment
- **ECS Native**: CodeDeploy不要のシンプル構成
- **無停止デプロイ**: ユーザーへの影響なし
- **自動ロールバック**: ヘルスチェック失敗時の自動復旧

### CI/CD パイプライン
- **GitHub Actions**: 自動化されたビルド・デプロイ
- **最小権限**: CloudTrail分析に基づく76個の権限
- **監査ログ**: 全デプロイ操作の追跡可能性