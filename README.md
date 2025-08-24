# NestJS Hannibal 3 - ハンニバルのアルプス越えルート

## AWS Architecture Diagram

<div align="center">
  <img src="docs/architecture/cacoo/architecture.svg" alt="AWS Architecture Diagram" width="800">
</div>

## 📋 ドキュメント

- [セットアップガイド](./docs/setup/README.md) - 環境構築・事前準備
- [運用ガイド](./docs/operations/README.md) - IAM管理・監視・分析
- [アーキテクチャ](./docs/architecture/mermaid/README.md) - システム構成図

<div align="center">
  <img src="docs/architecture/diagrams/latest.png?v=20250806165536" alt="AWS Architecture" width="600">
</div>

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

## 🚀 Amazon ECS 用の CodeDeploy デプロイメント

### デプロイモード
- **Canary**: 10%→100%段階的切替
- **Blue/Green**: 即座切替
- **Provisioning**: 初期構築

### 主要機能
- 1分高速デプロイ
- 失敗時自動ロールバック
- Production/Test環境切り替え
- GitHub Actions自動化

詳細は[デプロイメントガイド](./docs/deployment/codedeploy-blue-green.md)を参照

## 🔐 セキュリティ

- Permission Boundary
- CloudTrail監査
- AssumeRole権限分離
- 最小権限原則
- Infrastructure as Code