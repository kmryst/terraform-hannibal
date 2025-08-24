# NestJS Hannibal 3 - ハンニバルのアルプス越えルート

<div align="center">
  <img src="docs/screenshots/hannibal-route.png" alt="ハンニバルのアルプス越えルート" width="800">
</div>

## AWS Architecture Diagram

### 手動作成版（Cacoo）
<div align="center">
  <img src="docs/architecture/cacoo/architecture.svg" alt="AWS Architecture Diagram" width="800">
</div>

### 自動生成版（Python diagrams）
<div align="center">
  <img src="docs/architecture/diagrams/latest.png?v=20250806165536" alt="AWS Architecture" width="600">
</div>

## 📋 ドキュメント

- [セットアップガイド](./docs/setup/README.md) - 環境構築・事前準備
- [運用ガイド](./docs/operations/README.md) - IAM管理・監視・分析
- [アーキテクチャ](./docs/architecture/mermaid/README.md) - システム構成図

## 🚀 完全自動化デプロイメント

- **Infrastructure as Code**: Terraform完全管理
- **GitHub Actions**: プッシュ時自動デプロイ
- **Blue/Green + Canary**: 無停止デプロイ
- **自動ロールバック**: 失敗時即座復旧

## 🔧 技術スタック

### フロントエンド
- React + TypeScript
- GraphQL
- Vite

### バックエンド
- NestJS
- GraphQL + REST
- PostgreSQL

### インフラストラクチャ
- AWS ECS Fargate
- CloudFront + S3
- Application Load Balancer

### CI/CD
- GitHub Actions
- CodeDeploy Blue/Green
- Docker
- Terraform

詳細は[デプロイメントガイド](./docs/deployment/codedeploy-blue-green.md)を参照

## 🔐 セキュリティ

- Permission Boundary
- CloudTrail監査
- **Athena分析**: CloudTrail権限最適化
- AssumeRole権限分離