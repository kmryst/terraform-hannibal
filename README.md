# ハンニバルのアルプス越えルートアプリケーション

<div align="center">
  
![AWS](https://img.shields.io/badge/AWS-Route53%20%7C%20CloudFront%20%7C%20ALB%20%7C%20ECS%20%7C%20RDS%20%7C%20S3-orange?logo=amazon-aws)
![Terraform](https://img.shields.io/badge/Terraform-1.12.1-purple?logo=terraform)
![Docker](https://img.shields.io/badge/Docker-node:20--alpine-blue?logo=docker)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?logo=github-actions)
![TypeScript](https://img.shields.io/badge/TypeScript-5.8-blue?logo=typescript)
![NestJS](https://img.shields.io/badge/NestJS-10.0-red?logo=nestjs)
![React](https://img.shields.io/badge/React-19.0-blue?logo=react)

</div>

<div align="center">
  <img src="docs/screenshots/hannibal-route.png" alt="ハンニバルのアルプス越えルート" width="800">
</div>

<div align="center">
  <img src="docs/screenshots/hannibal_1_middle.gif" alt="ハンニバルデモ" width="800">
</div>

<br>

## 💡 プロジェクト概要

本番環境を想定したAWSインフラ構築の技術力を示すため、セキュア・スケーラブル・コスト最適化されたアーキテクチャを個人開発で実装。

歴史的ルートを可視化するWebアプリケーションを題材に、**実務で使われるAWSサービス構成で構築**。

**設計方針**: 
- 本番環境を想定したセキュアなネットワーク設計（3層VPC）
- コスト効率を重視した適切なサービス選定（Fargate 0.25vCPU）
- 完全自動化されたCI/CDパイプライン（Blue/Green + Canary対応）

**個人開発**: インフラストラクチャー、バックエンド、フロントエンドまですべて一人で設計、開発、運用。

<br>

## 🌐 デモサイト

[hamilcar-hannibal.click](https://hamilcar-hannibal.click) でライブデモをご覧いただけます。

**コスト最適化運用中** - アプリケーション層（ECS、RDS、ALB等）を停止することで、月額コストを約$30-50から**約$5以下**に削減。  
GitHub Actionsで**ワンクリック起動/停止**が可能（約15分でフル稼働）。  
デモご希望の際はお気軽にお声がけください😊

※基盤リソース（S3 State管理、CloudTrail等）は常時稼働

<br>

## AWS Architecture Diagram

<div align="center">
  <img src="docs/architecture/aws/cacoo/architecture.svg" alt="AWS Architecture Diagram" width="800">
</div>

<br>

## 🏗️ Infrastructure as Code

### インフラ規模
- **Terraformリソース数**: 約50リソース
- **月額コスト**: 約$30-50（停止時: 約$5以下）
- **デプロイ時間**: 約15分（Blue/Green切替: 5分）
- **コード行数**: Backend 5,000行 / Frontend 3,000行 / Terraform 2,000行

### Terraform 構成
```
terraform/
├── foundation/          # 基盤リソース
│   ├── iam.tf          # Permission Boundary + AssumeRole
│   ├── athena.tf       # CloudTrail分析
│   ├── billing.tf      # コスト監視
│   └── guardduty.tf    # 脅威検知（コスト削減のため無効化中）
├── environments/dev/    # 環境別設定
│   └── main.tf         # モジュール統合
└── modules/            # 再利用可能なモジュール
    ├── cdn/            # CloudFront
    ├── cicd/           # CodeDeploy Blue/Green
    ├── compute/        # ECS Fargate + ALB
    ├── networking/     # 3層VPC（Public/App/Data）+ Route53
    ├── observability/  # CloudWatch監視
    ├── security/       # Security Groups + IAM
    └── storage/        # RDS + S3
```

**State管理**: S3 + DynamoDB（Terraform State Lock）

<br>

## 🤖 GitHub Actions ワークフロー

### デプロイ（deploy.yml）
モード選択可能：
- **provisioning**: 初回構築（Blue環境のみ）
- **bluegreen**: 0% → 100%（一括切替）
- **canary**: 10% → 100%（5分間隔）

### デストロイ（destroy.yml）
- ワンクリックでAWSリソース削除

### 静的解析・ビルドチェック（pr-check.yml）
**自動実行**: プルリクエスト作成・更新時
- Backend: ESLint + Build
- Frontend: TypeScript + Build
- Terraform: Format + Validate

### SAST・SCAスキャン（security-scan.yml）
**自動実行**: プルリクエスト作成・更新時 + 毎週月曜0時（定期スキャン）
- 依存関係の脆弱性スキャン（Trivy）
- コンテナイメージスキャン（Trivy + Dockerキャッシュ）
- SASTスキャン（CodeQL）
- Terraformセキュリティスキャン（tfsec）
- シークレット漏洩検出（Gitleaks）
- 結果をGitHub Securityに統合

### アーキテクチャ図自動生成（architecture-diagram.yml）
- Python diagramsで構成図を自動更新

<br>

### デプロイ実行例（provisioningモード）

<div align="center">
  <img src="docs/screenshots/github-actions-demo.gif?v=20250108165536" alt="GitHub Actions Demo" width="800">
</div>

<br>

## 🔧 技術スタック

### インフラストラクチャ
- **IaC**: Terraform 1.12.1（モジュール化設計）
- **AWS**: ECS Fargate, RDS PostgreSQL, CloudFront, Route53
- **CI/CD**: GitHub Actions（Blue/Green + Canary対応）

### バックエンド
- **Framework**: NestJS 10.0 + TypeScript 5.8
- **API**: GraphQL（Code First）
- **Database**: PostgreSQL 15

### フロントエンド
- **Framework**: React 19.0 + TypeScript 5.8
- **Build**: Vite
- **Map**: Mapbox GL JS
- **API**: Apollo Client（GraphQL）

## 🔒 セキュリティ対策
- **IAM**: Permission Boundary + AssumeRole（最小権限の原則を実装）
- **ネットワーク**: 3層VPC + Private Subnet（DB層は外部非公開）
- **暗号化**: RDS暗号化 + Secrets Manager（認証情報の安全管理）
- **監査**: CloudTrail + Athena分析（全操作ログを90日間保持・分析可能）
- **脆弱性**: SAST/SCA 週次スキャン（Trivy + CodeQL + tfsec + Gitleaks）
- **WAF**: CloudFront + ALB対応（コスト削減のため無効化中）

## 💪 技術的な挑戦と成果

実務レベルのインフラ構築で直面した課題と、その解決を通じて得た学び：

- **Blue/Greenデプロイメント**: IAM権限の段階的追加により5分以内の無停止切替を実現
- **最小権限設計**: Permission Boundaryでセキュリティと自動化を両立
- **3層VPCアーキテクチャ**: NAT Gateway設計でDB層を完全非公開化
- **Terraform State管理**: S3 + DynamoDBでチーム開発に対応可能な基盤構築
- **依存関係の最適化**: リソース削除順序の制御で安全な環境破棄を実現

## 📋 ドキュメント

- [セットアップガイド](./docs/setup/README.md) - 環境構築・事前準備
- [デプロイメントガイド](./docs/deployment/codedeploy-blue-green.md) - Blue/Green/Canaryデプロイ手順
- [運用ガイド](./docs/operations/README.md) - IAM管理・監視・分析
- [アーキテクチャ](./docs/architecture/aws/mermaid/README.md) - システム構成図
- [トラブルシューティング](./docs/troubleshooting/README.md) - 実装時の課題と解決方法
- **[Contributing Guide](./CONTRIBUTING.md)** - Issue駆動開発フロー・貢献ガイド

## 🔧 GitHub運用

### Issue駆動開発
- Issue作成 → ブランチ作成 → 実装 → PR → マージの一連フロー
- Issueテンプレートで背景・要件・リスク・コストを記録
- PRテンプレートで変更内容・影響範囲を明確化
- 詳細は [CONTRIBUTING.md](./CONTRIBUTING.md) を参照

### テンプレート活用
- **Issueテンプレート**: 背景/目的、要件/スコープ、受け入れ条件、ダウンタイム、リスクレベル、コスト影響
- **PRテンプレート**: 目的、変更内容、影響範囲、影響チェック、ロールバック手順
- **Web UI / CLI 両対応**: GitHub Web UIとGitHub CLIのどちらでも起票可能

### ラベル管理
- **コード管理**: `.github/labels.yml` でラベルをInfrastructure as Code化
- **自動同期**: GitHub Actionsで自動的にラベルを同期
- **体系的な分類**: Type/Area/Risk/Cost/Priority/Statusの6カテゴリで整理
- **39個のラベル**: type:feature, area:infra, risk:low, cost:none など

### チーム開発フロー
- ブランチ命名規則: `feature/#issue番号-説明`
- コミットメッセージ: Conventional Commits形式
- PR本文に`Closes #issue番号`を記載して自動クローズ
- PRマージ後: `gh done XX` で自動的にmainに戻ってpull

---
**最終更新**: 2025年10月10日
