# GitHub Copilot Instructions

このプロジェクトでGitHub Copilotを使用する際の指示です。

## 🚨 絶対ルール: Issue駆動開発の徹底

**コード実装前に必ずGitHub Issueを作成または参照すること。**

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

## 開発フロー

### 1. Issue作成（必須第一ステップ）

```bash
gh issue create --title "[Type] 短い要約" --body "詳細" \
  --label "type:feature,area:infra,risk:low,cost:none"
```

**必須ラベル:**
- `type:*` - feature/bug/docs/infra/chore のいずれか
- `area:*` - frontend/backend/infra/ci-cd/github のいずれか
- `risk:*` - low/medium/high のいずれか
- `cost:*` - none/small/medium/large のいずれか

**含めるべき内容:**
- 背景・目的
- 要件定義
- 設計方針
- 変更予定ファイル
- 完了条件
- テスト計画

**ラベル追加方法（作成後に追加する場合）:**
```bash
gh issue edit <番号> --add-label "type:docs,area:github,risk:low,cost:none"
```

### 2. ブランチ作成

```bash
# 必ずIssue番号を含める
git checkout -b feature/#XX-description
```

### 3. 実装

Issue番号を常に意識してコードを書く。

### 4. PR作成

```bash
gh pr create --title "[Type] 要約" --body "Closes #XX" \
  --label "type:feature,area:infra,risk:low,cost:none"
```

**必須事項:**
- PR本文に `Closes #XX` を記載（Issueと自動連携）
- Issueと同じラベルを付与
- 変更内容の要約を記載
- 影響範囲を明記

### 5. マージ & mainブランチ更新

```bash
# 推奨: GitHub CLI Alias（PRマージ・mainへ戻る・pullを1コマンドで実行）
gh done XX

# 手動の場合
gh pr merge XX --merge
git checkout main
git pull origin main
```

**`gh done` エイリアスの設定方法:**

```bash
gh alias set done '!f() { gh pr merge "$1" --merge && git checkout main && git pull origin main; }; f'

# 確認
gh alias list
```

---

## コミットメッセージ規約

**Conventional Commits** 形式を使用：

```
type(scope): 説明

例:
feat: mainブランチ保護機能を追加
fix: ログインバグを修正
docs: READMEにセットアップ手順を追加
refactor: 認証ロジックを整理
infra: Terraform GitHub Provider追加
```

**Type一覧:**
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメント
- `refactor`: リファクタリング
- `test`: テスト
- `chore`: 雑務
- `ci`: CI/CD
- `infra`: インフラ

---

## コーディング規約

### TypeScript/NestJS

- **ファイル命名**: kebab-case (`user-auth.service.ts`)
- **クラス名**: PascalCase (`UserAuthService`)
- **関数/変数**: camelCase (`getUserById`)
- **定数**: UPPER_SNAKE_CASE (`MAX_RETRY_COUNT`)
- **型定義**: PascalCase + `Interface`/`Type` サフィックス (`UserInterface`)

### Terraform

- **ファイル命名**: kebab-case (`github-branch-protection.tf`)
- **リソース名**: スネークケース (`github_branch_protection`)
- **変数名**: スネークケース (`enable_branch_protection`)
- **モジュール名**: kebab-case (`modules/security`)

### React

- **コンポーネント**: PascalCase (`UserProfile.tsx`)
- **Hooks**: `use` プレフィックス (`useAuth.ts`)
- **スタイル**: CSS Modules (`UserProfile.module.css`)

---

## セキュリティ要件

### 絶対に含めてはいけない情報

❌ AWS Access Key / Secret Key  
❌ データベースパスワード  
❌ API トークン  
❌ プライベートキー  

### 秘密情報の管理

✅ AWS Secrets Manager / SSM Parameter Store を使用  
✅ 環境変数で管理 (`.env` は `.gitignore` に追加)  
✅ Terraform は `terraform.tfvars` を `.gitignore` に追加  

---

## インフラ変更時の注意

### Terraform

- `terraform plan` で必ず変更内容を確認
- 本番環境変更は慎重に（ダウンタイム影響を考慮）
- State ファイルは S3 で管理（直接編集禁止）

### AWS

- コスト影響を常に意識（Issue に `cost:*` ラベル付与）
- リソース削除前にバックアップ確認
- セキュリティグループは最小権限の原則

---

## テスト要件

### バックエンド (NestJS)

```bash
# ユニットテスト
npm run test

# E2Eテスト
npm run test:e2e

# カバレッジ
npm run test:cov
```

### フロントエンド (React)

```bash
cd client
npm run test
```

### インフラ (Terraform)

```bash
cd terraform/foundation
terraform plan
terraform validate
```

---

## ドキュメント更新

コード変更時は関連ドキュメントも必ず更新：

- `README.md`: プロジェクト概要、セットアップ手順
- `docs/`: 詳細な設計・運用ドキュメント
- コード内コメント: 複雑なロジックには説明を追加

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

**最終更新**: 2025年10月10日
