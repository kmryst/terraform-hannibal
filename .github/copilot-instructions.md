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

## 🚨 絶対ルール: Issue駆動開発の徹底

**コード実装前に必ずGitHub Issueを作成または参照すること。**

### Issue / PR テンプレートの強制使用

❗ Issueは必ず既定のテンプレートを使用すること（Web UIのテンプレート選択、またはCLIの `--template` / `--body-file` を利用）。

- CLI例（feature request テンプレート）:

  ```bash
  ./scripts/github/create-issue-with-labels.sh \
    --title "[Docs] 要約" \
    --body-file docs/issue-templates/feature_request.md \
    --type type:docs \
    --area area:docs \
    --risk risk:low \
    --cost cost:none
  ```

  CLI でテンプレ本文を扱う場合は `.github/tmp/` 配下に一時ファイルを作成し、起票後すぐ削除すること（例: `.github/tmp/issue-<summary>.md`）。
  
  **一時ファイル削除時の必須ルール:**
  - 削除理由を必ず明示すること（例: "Issue起票に使った一時ファイルを削除（CONTRIBUTINGガイドに従う）"）
  - `run_in_terminal` の `explanation` パラメータで理由を説明
  - ユーザーが意図を理解できるよう、何を削除するか・なぜ削除するかを明確に伝える

❗ Pull Request も必ずテンプレートを適用すること（Web UIでのテンプレート選択、またはCLIで `--body-file .github/pull_request_template.md` を指定）。

- PowerShell推奨例（Issue番号自動埋め込み）:

  ```powershell
  ./scripts/github/create-pr-with-labels.sh `
    --title "[Docs] 要約" `
    --body-file .github/pull_request_template.md `
    --issue XX `
    --type type:docs `
    --area area:docs `
    --risk risk:low `
    --cost cost:none `
    --base main
  ```

テンプレートを外した状態でのIssue/PR作成は禁止。例外が必要な場合は事前にオーナーへ相談し、承認を得ること。

### 禁止事項

❌ いきなりコードを書く  
❌ Issue番号なしでブランチを作成する  
❌ `Closes #XX` なしでPRを作成する

### 必須事項

✅ まずIssueを作成  
✅ Issue番号をブランチ名に含める (`feature/#XX-description`)  
✅ PRに `Closes #XX` を記載  
✅ `CONTRIBUTING.md` のフローに従う

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

## 🚀 開発ワークフロー（Issue駆動開発）

### 1. Issue作成（必須第一ステップ）

```bash
./scripts/github/create-issue-with-labels.sh \
  --title "[Feature] 要約" \
  --body-file docs/issue-templates/feature_request.md \
  --type type:feature \
  --area area:backend \
  --risk risk:low \
  --cost cost:none
```

**必須ラベル4種類:**
- `type:*` - feature/bug/docs/infra/chore
- `area:*` - frontend/backend/infra/ci-cd/github
- `risk:*` - low/medium/high
- `cost:*` - none/small/medium/large

### 2. ブランチ作成 → 実装

```bash
git checkout -b feature/#XX-description
# 実装...
git add .
git commit -m "feat: 新機能を追加"  # Conventional Commits
```

### 3. PR作成（PowerShell推奨）

```powershell
./scripts/github/create-pr-with-labels.sh `
  --title "[Feature] 要約" `
  --body-file .github/pull_request_template.md `
  --issue XX `
  --type type:feature `
  --area area:backend `
  --risk risk:low `
  --cost cost:none `
  --base main
```

### 4. マージ & 自動クリーンアップ

```bash
# 推奨: GitHub CLI Alias
gh done XX

# Alias設定方法
gh alias set done '!f() { gh pr merge "$1" --merge && git checkout main && git pull origin main; }; f'
```

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

## 🔒 セキュリティ要件（絶対遵守）

### 秘密情報の絶対禁止

❌ **コミットしてはいけない情報:**
- AWS Access Key / Secret Key
- データベースパスワード（RDSはSecrets Managerで管理）
- Mapbox API Token（環境変数で管理）
- `.env` ファイル（`.gitignore`に追加済み）
- `terraform.tfvars`（`.gitignore`に追加済み）

✅ **正しい管理方法:**
```bash
# 環境変数で管理
export DATABASE_URL="postgresql://..."
export MAPBOX_TOKEN="pk.xxx"

# AWS Secrets Manager使用（本番環境）
aws secretsmanager get-secret-value --secret-id hannibal-db-credentials
```

### IAM最小権限の原則

**IAM構成** (`terraform/foundation/iam.tf`):
```
hannibal (IAM User)
  └─ AssumeRole → HannibalDeveloperRole-Dev (手動操作用)

hannibal-cicd (IAM User)
  └─ AssumeRole → HannibalCICDRole-Dev (GitHub Actions用)
       └─ Permission Boundary: HannibalCICDBoundary
```

**Permission Boundary**: ECS/RDS/S3のみ操作可能、IAM/Billing/GuardDuty は禁止。

### セキュリティスキャン（自動実行）

**GitHub Actions**: `security-scan.yml`
- **CodeQL**: ソースコード脆弱性（SAST）
- **Trivy**: Dockerイメージ脆弱性（SCA）
- **tfsec**: Terraform設定ミス検出（IaC）
- **Gitleaks**: シークレット漏洩検出

**実行タイミング:**
- PR作成時（必須チェック）
- 週次スケジュール実行
- 検出結果は GitHub Security タブへ集約

---

## 🧪 テスト戦略

### Backend (NestJS)

```typescript
// Unit Test例: route.service.spec.ts
describe('RouteService', () => {
  it('should return all routes', async () => {
    const routes = await service.findAll();
    expect(routes).toBeDefined();
  });
});

// E2E Test例: app.e2e-spec.ts
it('/graphql (POST) - query routes', () => {
  return request(app.getHttpServer())
    .post('/graphql')
    .send({ query: '{ routes { id name } }' })
    .expect(200);
});
```

**テスト実行:**
```bash
npm test              # Jest Unit Tests
npm run test:e2e      # E2E Tests
npm run test:cov      # Coverage Report
```

### Infrastructure (Terraform)

```bash
# 構文チェック
terraform validate

# セキュリティスキャン
tfsec terraform/

# 変更プレビュー（破壊的変更の確認）
terraform plan -out=tfplan
```

---

## 📊 コスト最適化戦略

### 停止運用による大幅コスト削減

**通常稼働時**: 月額 $30-50
- ECS Fargate: 0.25vCPU / 0.5GB ($15-20)
- RDS t4g.micro: ($10-15)
- ALB: ($18)
- NAT Gateway: ($32)

**停止時**: 月額 $5以下
- S3 (Terraform State): ($1)
- CloudTrail: ($2)
- Route53: ($1)
- 基盤リソース: ($1-2)

**停止方法** (`terraform/foundation/billing.tf` 参照):
```bash
# GitHub Actions: destroy.yml で実行
# または手動:
cd terraform/environments/dev
terraform destroy -target=module.compute
terraform destroy -target=module.storage
```

**起動方法**:
```bash
# GitHub Actions: deploy.yml (provisioning モード)
```

---

## 🔍 トラブルシューティング

### よくある問題と解決方法

#### 1. ECS Task起動失敗
```bash
# CloudWatch Logs確認
aws logs tail /ecs/nestjs-hannibal-3 --follow

# 原因: DATABASE_URL環境変数未設定
# 解決: Secrets Manager確認 or Task Definition更新
```

#### 2. Terraform State Lock
```bash
# DynamoDB Lock確認
aws dynamodb scan --table-name terraform-state-lock

# 強制解除（注意: 他の操作がないことを確認）
terraform force-unlock <LOCK_ID>
```

#### 3. CodeDeploy Blue/Green失敗
```bash
# デプロイ履歴確認
aws deploy list-deployments --application-name nestjs-hannibal-3-app

# ロールバック
aws deploy stop-deployment --deployment-id <ID> --auto-rollback-enabled
```

**詳細**: `docs/troubleshooting/README.md` 参照

---

## 🔑 コーディング規約

### TypeScript/NestJS
- **ファイル命名**: kebab-case (`route.service.ts`)
- **クラス名**: PascalCase (`RouteService`)
- **デコレータ**: `@Module()`, `@Resolver()`, `@Query()`
- **GraphQL Code First**: Resolver優先、Schema自動生成

### Terraform
- **ファイル命名**: kebab-case (`ecs-fargate.tf`)
- **リソース名**: スネークケース (`aws_ecs_service.main`)
- **変数名**: スネークケース (`enable_blue_green`)
- **モジュール**: `modules/` 配下で再利用可能に設計

### Git Commit
**Conventional Commits**:
```
feat: GraphQL Resolverに新エンドポイント追加
fix: ECS Task Definition のメモリ設定修正
docs: README.md にデプロイ手順追記
infra: Terraform に CloudWatch Alarm追加
```

---

## 📚 ドキュメント構造

コード変更時は関連ドキュメントも必ず更新：

```
docs/
├── architecture/          # システム設計書
│   ├── system-design.md   # 全体アーキテクチャ
│   ├── data-architecture.md
│   └── aws/              # AWS構成図（自動生成）
├── deployment/           # デプロイ手順
│   └── codedeploy-blue-green.md  # Blue/Green詳細
├── operations/           # 運用手順
│   └── README.md         # IAM管理・監視・分析
├── security/             # セキュリティ設計
│   └── iam-analysis/
├── setup/                # 環境構築
│   └── README.md
└── troubleshooting/      # トラブルシュート
    └── README.md         # 実装時の課題と解決方法
```

---

## 参考ドキュメント

プロジェクト内の重要ドキュメント：

- **[CONTRIBUTING.md](../CONTRIBUTING.md)** - 貢献ガイド（必読）
- **[README.md](../README.md)** - プロジェクト概要
- **[docs/architecture/](../docs/architecture/)** - アーキテクチャ設計
- **[docs/deployment/](../docs/deployment/)** - デプロイ手順
- **[docs/security/](../docs/security/)** - セキュリティ設計

---

## AI アシスタント（GitHub Copilot）への特記事項

### コード生成時の優先順位

1. **Issue駆動**: Issue番号なしで実装しない
2. **セキュリティ**: 秘密情報を含めない
3. **品質**: テストコードも一緒に生成
4. **ドキュメント**: コメント・ドキュメント更新も忘れずに

### 提案時の確認事項

- [ ] Issueが存在するか確認
- [ ] 変更がプロジェクト規約に準拠しているか
- [ ] セキュリティリスクがないか
- [ ] コスト影響がないか（インフラ変更時）
- [ ] テストが必要か
- [ ] ドキュメント更新が必要か

---

**最終更新**: 2025年10月11日
