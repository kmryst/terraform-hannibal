# ハンニバルのアルプス越えルートアプリケーション
A production-like AWS infrastructure portfolio with Terraform, ECS Fargate, Blue/Green CI/CD, and security automation.

## 採用向けサマリー（30秒）
- 対象ロール: SRE / プラットフォーム / インフラ（Terraform × AWS × GitHub Actions）
- 実績: 無停止リリース（Blue/Green/Canary）約5分切替、停止運用で月額約$30-50→停止時約$5、PRトリガー＋週次脆弱性スキャン運用
- 再現性: S3+DynamoDBでState管理、ワンクリック起動/停止、IaC標準化（モジュール化・レビュー基準・運用SOP）
- デモ: [hamilcar-hannibal.click](https://hamilcar-hannibal.click)
- 起動目安: GitHub Actions経由で約15分（Blue/Green provisioning）

## 5分で確認（デモと証跡）
- Actions: `deploy.yml` の provisioning モードで起動（完了まで約15分）
- 稼働確認: CloudFront/アプリURL [hamilcar-hannibal.click](https://hamilcar-hannibal.click) で動作を確認
- Blue/Green履歴: CodeDeployとGitHub Actionsログで切替結果を確認
- セキュリティ検証: SecurityタブでCodeQL/Trivy/tfsec/Gitleaksの検出と修正履歴を確認
- 補足: docs/architecture/ の図、docs/security/ のレポート、docs/troubleshooting/ のメモで静的成果物を参照

## 設計判断の理由
- コスト最適化: Fargate 0.25vCPUと停止運用で月額約$30-50→停止時約$5を実現
- リリース戦略: Blue/Green/Canaryで段階的移行と即時ロールバックを両立し、約5分の無停止切替
- セキュリティ運用: PRトリガーと週次でCodeQL/Trivy/tfsec/Gitleaksを自動実行し検知から修正まで継続

## スクリーンショット
- Actions実行履歴: docs/images/actions-deploy.png
- Blue/Green切替履歴: docs/images/bluegreen-history.png
- Securityレポート例: docs/images/security-report.png
- アーキテクチャ図: docs/images/architecture-latest.png（GitHub Actionsで自動更新）

## インシデントノート（3件）
- CodeDeploy権限不足 → 段階的拡張で無停止5分切替を安定化
- RDS削除順の依存性 → Destroy順制御でエラーなく破棄可能に
- NATコストとDB非公開 → 3層VPCとルート最適化で整合

## 既存ドキュメント（詳細）

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

**プロジェクト概要**

本番環境を想定したAWSインフラ構築の技術力を示すため、セキュア・スケーラブル・コスト最適化されたアーキテクチャを個人開発で実装。歴史的ルートを可視化するWebアプリケーションを題材に、実務で使われるAWSサービス構成で構築。インフラストラクチャー、バックエンド、フロントエンドまですべて一人で設計・開発・運用。

**設計方針**
- 本番環境を想定したセキュアなネットワーク設計（3層VPC）
- コスト効率を重視したサービス選定（Fargate 0.25vCPU）
- 完全自動化されたCI/CDパイプライン（Blue/Green + Canary対応）

**デモサイト**
- [hamilcar-hannibal.click](https://hamilcar-hannibal.click) でライブデモを公開
- アプリケーション層を停止し月額コストを約$30-50から約$5以下に最適化
- GitHub Actionsでワンクリック起動/停止（起動完了まで約15分）
- 基盤リソース（S3 State管理、CloudTrail等）は常時稼働

**AWS Architecture Diagram**

<div align="center">
  <img src="docs/architecture/aws/cacoo/architecture.svg" alt="AWS Architecture Diagram" width="800">
</div>

**Infrastructure as Code**
- Terraformリソース数: 約50リソース
- 月額コスト: 約$30-50（停止時約$5以下）
- デプロイ時間: 約15分（Blue/Green切替5分）
- コード行数: Backend 5,000行 / Frontend 3,000行 / Terraform 2,000行

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

State管理: S3 + DynamoDB（Terraform State Lock）

**GitHub Actions ワークフロー**
- deploy.yml: provisioning / bluegreen / canary を選択可能
- destroy.yml: ワンクリックでAWSリソース削除
- pr-check.yml: Backend ESLint+Build、Frontend TypeScript+Build、Terraform Format+Validate
- security-scan.yml: PR時と週次でCodeQL、Trivy、tfsec、Gitleaksを実行しGitHub Securityへ集約
- architecture-diagram.yml: Python diagramsで構成図を自動更新

<div align="center">
  <img src="docs/screenshots/github-actions-demo.gif?v=20250108165536" alt="GitHub Actions Demo" width="800">
</div>

**技術スタック**
- インフラ: Terraform 1.12.1、AWS（ECS Fargate / RDS PostgreSQL / CloudFront / Route53）
- CI/CD: GitHub Actions（Blue/Green + Canary対応）
- バックエンド: NestJS 10.0、TypeScript 5.8、GraphQL Code First、PostgreSQL 15
- フロントエンド: React 19.0、TypeScript 5.8、Vite、Mapbox GL JS、Apollo Client

**セキュリティ対策**
- IAM: Permission Boundary + AssumeRoleで最小権限を徹底
- ネットワーク: 3層VPCとPrivate SubnetでDB層を外部非公開
- 暗号化: RDS暗号化とSecrets Managerで認証情報を管理
- 監査: CloudTrail + Athena分析で全操作ログを90日保持
- 脆弱性: CodeQL、Trivy、tfsec、Gitleaksを組み合わせたSAST/SCA/Secrets/IaCスキャン
- WAF: CloudFront + ALB対応（コスト最適化のため現在無効化）

**技術的な挑戦と成果**
- Blue/Greenデプロイメント: IAM権限の段階的追加で5分以内の無停止切替を実現
- 最小権限設計: Permission Boundaryでセキュリティと自動化を両立
- 3層VPCアーキテクチャ: NAT Gateway設計でDB層を完全非公開化
- Terraform State管理: S3 + DynamoDBでチーム開発に対応可能な基盤を構築
- 依存関係の最適化: リソース削除順序の制御で安全に環境破棄

**参考ドキュメント**
- [docs/setup/README.md](./docs/setup/README.md): 環境構築・事前準備
- [docs/deployment/codedeploy-blue-green.md](./docs/deployment/codedeploy-blue-green.md): Blue/Green/Canaryデプロイ手順
- [docs/operations/README.md](./docs/operations/README.md): IAM管理・監視・分析
- [docs/architecture/aws/mermaid/README.md](./docs/architecture/aws/mermaid/README.md): システム構成図
- [docs/troubleshooting/README.md](./docs/troubleshooting/README.md): 実装時の課題と解決方法
- [CONTRIBUTING.md](./CONTRIBUTING.md): Issue駆動開発フロー・貢献ガイド

**GitHub運用**
- Issue作成 → ブランチ作成 → 実装 → PR → マージの一連フローを徹底
- Issueテンプレートで背景・要件・リスク・コストを記録し、PRテンプレートで影響範囲とロールバック手順を明記
- `.github/labels.yml` でラベルをコード管理し、GitHub Actionsで自動同期
- ブランチは `feature/#issue番号-説明`、コミットはConventional Commits、PR本文に `Closes #issue番号`
- `gh done XX` でPRマージ後にmainへ戻り最新を取得

---
**最終更新**: 2025年10月11日 15:28 JST
