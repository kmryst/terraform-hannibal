# GitHub Copilot Instructions

このプロジェクトでGitHub Copilotを使用する際の指示です。

## 🎯 プロジェクト概要

**ハンニバルのアルプス越えルート可視化アプリケーション** - 本番環境を想定したAWSインフラ構築ポートフォリオ

### 技術スタック
- **Frontend**: React 19 + TypeScript 5.8 + Vite + Mapbox GL JS + Apollo Client
- **Backend**: NestJS 10 + TypeScript 5.8 + GraphQL (Code First) + TypeORM
- **Database**: PostgreSQL 15 (RDS)
- **Infrastructure**: Terraform 1.12.1 + AWS (ECS Fargate / ALB / CloudFront / Route53)
- **CI/CD**: GitHub Actions (Blue/Green & Canary Deployment)

### アーキテクチャパターン
```
CloudFront (CDN) → ALB → ECS Fargate (Blue/Green) → RDS PostgreSQL
                    ↓
                S3 (Static Assets)
```

**重要**: 3層VPCアーキテクチャ (Public/App/Data) でDB層は完全非公開。

---

## 🏗️ プロジェクト構造（重要なアーキテクチャ決定）

### モノレポ構成（Backend + Frontend）
```
nestjs-hannibal-3/
├── src/                    # NestJS Backend (GraphQL API)
│   ├── modules/           # 機能別モジュール (route, map)
│   │   └── route/
│   │       ├── route.resolver.ts   # GraphQL Resolver (@Query, @Mutation)
│   │       ├── route.service.ts
│   │       └── route.module.ts
│   ├── entities/          # TypeORM Entity (DB定義)
│   ├── graphql/           # GraphQL Schema自動生成先
│   └── main.ts            # CORS設定（CLIENT_URL環境変数必須）
├── client/                # React Frontend (Vite)
│   ├── src/
│   │   ├── apollo/       # Apollo Client設定
│   │   ├── components/   # React Components
│   │   └── services/     # API Service層
│   └── vite.config.ts
├── terraform/            # Infrastructure as Code
│   ├── foundation/       # 基盤IAM・監視（S3 State管理）
│   │   ├── iam.tf       # Permission Boundary + AssumeRole
│   │   ├── billing.tf   # コスト監視 ($30-50 → 停止時$5)
│   │   └── athena.tf    # CloudTrail分析
│   ├── modules/         # 再利用可能モジュール
│   │   ├── networking/  # 3層VPC (Public/App/Data)
│   │   ├── compute/     # ECS Fargate + ALB
│   │   ├── cicd/        # CodeDeploy Blue/Green
│   │   ├── storage/     # RDS + S3
│   │   ├── cdn/         # CloudFront
│   │   ├── security/    # Security Groups
│   │   └── observability/ # CloudWatch
│   └── environments/dev/  # 環境別設定
├── .github/workflows/
│   ├── deploy.yml         # 3モード対応 (provisioning/bluegreen/canary)
│   ├── security-scan.yml  # CodeQL/Trivy/tfsec/Gitleaks
│   └── pr-check.yml       # Lint + Build
├── appspec.yml           # CodeDeploy設定
└── Dockerfile            # Multi-stage build (node:20-alpine)
```

### 重要なアーキテクチャ決定

1. **GraphQL Code First**: `route.resolver.ts`でデコレータ駆動開発、スキーマは自動生成
2. **TypeORM + PostgreSQL**: `app.module.ts`でDATABASE_URL環境変数から接続
3. **CORS設定**: `main.ts`で環境別Origin制御（本番=CLIENT_URL、開発=localhost:5173）
4. **IAM最小権限**: `foundation/iam.tf`でPermission Boundary + HannibalCICDRole
5. **Blue/Green Deployment**: `modules/cicd/`でCodeDeploy、約5分で無停止切替
6. **State管理**: S3 + DynamoDB Lock（`terraform/foundation/`で初期化）

---

## 💻 ローカル開発環境

### Backend開発 (NestJS)

```bash
# 依存関係インストール
npm ci

# 開発サーバー起動（ホットリロード）
npm run start:dev  # http://localhost:3000/graphql

# テスト実行
npm test           # Unit Tests
npm run test:e2e   # E2E Tests
npm run test:cov   # Coverage Report

# Lint & Build
npm run lint
npm run build
```

**環境変数（`.env`）:**
```bash
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://user:pass@localhost:5432/hannibal
DEV_CLIENT_URL_LOCAL=http://localhost:5173
```

### Frontend開発 (React + Vite)

```bash
cd client
npm ci
npm run dev        # http://localhost:5173
npm run build      # 本番ビルド
```

**Apollo Client設定**: `client/src/apollo/` で GraphQL エンドポイント接続

### Infrastructure開発 (Terraform)

```bash
cd terraform/environments/dev
terraform init     # S3バックエンド初期化
terraform plan     # 変更プレビュー
terraform apply    # リソース作成

# State確認
terraform state list
terraform state show aws_ecs_service.main
```

**重要**: Terraform State は S3 で管理、DynamoDB でロック。直接編集禁止。

---

## 🚢 デプロイメント（GitHub Actions）

### 3つのデプロイモード

#### 1. Provisioning（初期構築）
```bash
# GitHub Actions: deploy.yml で選択
deployment_mode: provisioning
```
- **目的**: 初回環境構築（Terraform apply + Docker Push + ECS起動）
- **所要時間**: 約15分
- **結果**: Blue環境のみ作成、80番ポートでサービス開始

#### 2. Blue/Green Deployment（無停止切替）
```bash
deployment_mode: bluegreen
```
- **目的**: 新バージョンを並行環境で起動 → 即座切替
- **所要時間**: 約5分で切替完了
- **仕組み**: CodeDeploy が Green 環境作成 → ALB Target Group 切替 → Blue 削除
- **ロールバック**: 1分以内に旧バージョンへ復旧可能

#### 3. Canary Deployment（段階的配信）
```bash
deployment_mode: canary
```
- **目的**: 10% → 100% の段階的トラフィック移行
- **所要時間**: 10%で1分待機 → 100%切替で合計約7分
- **仕組み**: CodeDeploy が 10% トラフィックで検証 → CloudWatch メトリクス確認 → 残り 90% 移行

### デプロイフロー詳細

```
GitHub Actions (deploy.yml)
  ↓
1. Test実行 (npm test)
  ↓
2. AWS認証 (Assume HannibalCICDRole)
  ↓
3. Terraform Apply (Infrastructure更新)
  ↓
4. Docker Build + ECR Push
  ↓
5. ECS Task Definition作成
  ↓
6. CodeDeploy実行 (Blue/Green or Canary)
  ↓
7. ALB Health Check (5回成功で切替)
  ↓
8. デプロイ完了 (旧環境削除)
```

**重要ファイル:**
- `appspec.yml`: CodeDeploy Hooks設定
- `scripts/hooks/*.sh`: デプロイ前後の検証スクリプト
- `terraform/modules/cicd/`: CodeDeploy Application/Deployment Group定義

---
