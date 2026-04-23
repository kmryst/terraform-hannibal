# Contributing Guide

本プロジェクトへの貢献ガイドです。Issue駆動開発のワークフローを説明します。

---

## 🚀 開発フロー（Issue駆動開発）

### 1. Issue作成

新しい機能追加やバグ修正は、必ずIssueから始めます。

```bash
gh issue create --title "[Type] 短い要約" \
  --body-file docs/issue-templates/feature_request.md \
  --label "type:feature,area:infra,risk:low,cost:none"
```

**Issueテンプレート**:
- `.github/ISSUE_TEMPLATE/feature_request.yml` (Web UI用)
- `docs/issue-templates/feature_request.md` (CLI用 `--body-file`)

---

### 2. ブランチ作成

Issueに基づいてブランチを作成します。

```bash
# ブランチ命名規則: feature/#issue番号-説明
git checkout -b feature/#XX-short-description
```

**例**:
```bash
# Issue #38: README更新
git checkout -b feature/#38-update-readme
```

---

### 3. 実装・コミット

コードを実装し、Conventional Commits形式でコミットします。

```bash
git add .
git commit -m "type: 変更内容の説明"
```

**Conventional Commits の Type**:
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメント修正
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `chore`: その他雑務
- `ci`: CI/CD変更
- `infra`: インフラ変更

**例**:
```bash
git commit -m "feat: ユーザー認証機能を追加"
git commit -m "fix: ログイン時のバリデーションエラーを修正"
git commit -m "docs: README.mdにセットアップ手順を追加"
```

---

### 4. プッシュ

リモートリポジトリにプッシュします。

```bash
git push -u origin feature/#XX-short-description
```

---

### 5. Pull Request作成

PRテンプレートを使ってPRを作成します。

**PowerShell推奨例**（Issue番号自動埋め込み）:
```powershell
gh pr create --title "[Type] 短い要約" `
  --body "$(Get-Content .github/pull_request_template.md -Raw)`n`nCloses #XX" `
  --label type:feature --label area:backend --label risk:low --label cost:none
```

**bash/zsh例**:
```bash
gh pr create --title "[Type] 短い要約" \
  --body "$(cat .github/pull_request_template.md)"$'\n\n'"Closes #XX" \
  --label type:feature --label area:backend --label risk:low --label cost:none
```

**PRテンプレート項目** (`.github/pull_request_template.md`):
- 目的
- 変更内容
- 影響範囲
- 影響チェック（ダウンタイム/コスト/リスク）
- 可観測性/検証
- ロールバック手順
- `Closes #XX` （Issue自動クローズ）

**必須ラベル4種類**:
- `type:*` - feature/bug/docs/infra/chore
- `area:*` - frontend/backend/infra/ci-cd/docs
- `risk:*` - low/medium/high
- `cost:*` - none/small/medium/large

---

### 6. マージ & main更新

PRがマージされたら、mainブランチに戻って最新を取得します。

#### 🎯 推奨: GitHub CLI Alias

```bash
# PRマージ・mainへ戻る・pullを1コマンドで実行
gh done XX
```

#### 手動の場合

```bash
gh pr merge XX --merge
git checkout main
git pull origin main
```

---

### 7. 次のIssueへ

mainブランチから次のIssue用ブランチを作成します。

```bash
gh issue create --title "[Type] 次のタスク"
git checkout -b feature/#YY-next-task
```

---

## 📋 開発フロー図

```
┌─────────────────────────────────────────────┐
│ 1. Issue作成                                 │
│    gh issue create --title "..."             │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 2. ブランチ作成                              │
│    git checkout -b feature/#XX-description   │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 3. 実装・コミット                            │
│    git add . && git commit -m "type: msg"    │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 4. プッシュ                                  │
│    git push -u origin feature/#XX            │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 5. PR作成                                    │
│    gh pr create --title "..." --base main    │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 6. マージ & main更新                         │
│    gh done XX                                │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 7. 次のIssueへ（1に戻る）                    │
└─────────────────────────────────────────────┘
```

---

## 🏷️ ラベル管理

ラベルは `.github/labels.yml` でコード管理されています。

### ラベル体系

#### Type（必須）
- `type:feature` - 新機能
- `type:bug` - バグ修正
- `type:docs` - ドキュメント
- `type:infra` - インフラ変更
- `type:chore` - その他雑務

#### Area
- `area:frontend` - フロントエンド
- `area:backend` - バックエンド
- `area:infra` - インフラ
- `area:ci-cd` - CI/CD

#### Risk
- `risk:low` - 低リスク
- `risk:medium` - 中リスク
- `risk:high` - 高リスク

#### Cost
- `cost:none` - コスト影響なし
- `cost:small` - 小額（月$10以下）
- `cost:medium` - 中額（月$10-50）
- `cost:large` - 高額（月$50以上）

#### Priority
- `priority:critical` - 緊急
- `priority:high` - 高優先度
- `priority:medium` - 中優先度
- `priority:low` - 低優先度

### ラベルの追加・変更

`.github/labels.yml` を編集してmainにマージすると、GitHub Actionsが自動的にラベルを同期します。

---

## 🔧 便利なエイリアス

### GitHub CLI Alias

```bash
# PRマージ & main更新
gh done XX

# 設定方法
gh alias set done '!f() { gh pr merge "$1" --merge && git checkout main && git pull origin main; }; f'
```

---

## ✅ チェックリスト

開発を始める前に確認してください：

- [ ] mainブランチにいるか確認（`git branch --show-current`）
- [ ] 最新のmainを取得済みか（`git pull origin main`）
- [ ] Issueを作成したか
- [ ] ブランチ名が `feature/#XX-description` 形式か
- [ ] コミットメッセージがConventional Commits形式か
- [ ] PR本文に `Closes #XX` を記載したか

---

## 📚 関連ドキュメント

- [README.md](./README.md) - プロジェクト概要
- [Issue Template](./.github/ISSUE_TEMPLATE/feature_request.yml) - Issue作成ガイド
- [PR Template](./.github/pull_request_template.md) - PR作成ガイド
- [Labels](./.github/labels.yml) - ラベル定義

---

## 🤝 サポート

質問や提案がある場合は、Issueを作成してください。

```bash
gh issue create --title "[Question] 質問内容"
```

---

**最終更新**: 2025年10月10日
