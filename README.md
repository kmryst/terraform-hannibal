# ハンニバルのアルプス越えルートアプリケーション

<div align="center">
  <img src="docs/screenshots/hannibal-route.png" alt="ハンニバルのアルプス越えルート" width="800">
</div>

<div align="center">
  <img src="docs/screenshots/hannibal_1_middle.gif" alt="ハンニバルデモ" width="800">
</div>

<br>

## 💡 プロジェクト概要

歴史的ルートを可視化するWebアプリケーションを題材に、**実務で使われるAWSサービス構成で構築**。

<br>

## 🌐 デモサイト

[hamilcar-hannibal.click](https://hamilcar-hannibal.click) でライブデモをご覧いただけます。

**現在停止中** - コスト効率化のため、現在はAWSリソースを停止しています。  
GitHub Actionsでワンクリック**デプロイ・デストロイ**が可能です。
デモご希望の際はお声がけください😊

<br>

## AWS Architecture Diagram

<div align="center">
  <img src="docs/architecture/aws/cacoo/architecture.svg" alt="AWS Architecture Diagram" width="800">
</div>

## 📋 ドキュメント

- [セットアップガイド](./docs/setup/README.md) - 環境構築・事前準備
- [運用ガイド](./docs/operations/README.md) - IAM管理・監視・分析
- [アーキテクチャ](./docs/architecture/aws/mermaid/README.md) - システム構成図

<br>

## 🏗️ Infrastructure as Code

### Terraform 構成
```
terraform/
├── foundation/          # 基盤リソース（IAM、Athena、DynamoDB）
│   ├── iam.tf          # Permission Boundary + AssumeRole設計
│   └── athena.tf       # CloudTrail分析基盤
├── environments/dev/    # 環境別設定
│   └── main.tf         # モジュール統合
└── modules/            # 再利用可能なモジュール
    ├── compute/        # ECS Fargate + ALB
    ├── networking/     # 3層VPC（Public/App/Data）
    ├── security/       # Security Groups + IAM
    ├── storage/        # RDS + S3
    └── cicd/           # CodeDeploy Blue/Green
```

<br>

## 🚀 CI/CD パイプライン

### デプロイモード
- **provisioning**: 初回構築（Blue環境のみ）
- **bluegreen**: 0% → 100%（即座切替）
- **canary**: 10% → 100%（5分間隔）

### GitHub Actions ワークフロー

<div align="center">
  <img src="docs/screenshots/github-actions-demo.gif?v=20250108165536" alt="GitHub Actions Demo" width="800">
</div>

### 技術的工夫
- **AssumeRole**: GitHub Actions は最小権限ユーザー、デプロイ時のみロール取得
- **Permission Boundary**: CI/CDロールの権限上限を制限
- **CloudTrail分析**: Athena で実際の権限使用を分析し、最小権限化

<br>

## 🔧 技術スタック

### フロントエンド
- React + TypeScript
- GraphQL
- Vite
- Mapbox

### バックエンド
- NestJS
- GraphQL
- PostgreSQL

詳細は[デプロイメントガイド](./docs/deployment/codedeploy-blue-green.md)を参照

## 🔐 セキュリティ

- Permission Boundary
- CloudTrail監査
- **Athena分析**: CloudTrail権限最適化
- AssumeRole権限分離
- CloudWatch監視
- GuardDuty脅威検知

<br>

## 📊 自動生成アーキテクチャ図

<div align="center">
  <img src="docs/architecture/aws/diagrams/latest.png?v=20250806165536" alt="AWS Architecture (Python diagrams)" width="800">
</div>