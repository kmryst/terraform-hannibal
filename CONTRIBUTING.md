# Contributing Guide

本プロジェクトへの貢献ガイドです。Issue駆動開発のワークフローを説明します。
設計意図や未採用案、将来の再検討条件は [docs/operations/github-flow-guardrails.md](./docs/operations/github-flow-guardrails.md) を参照してください。

---

## 🚀 開発フロー（Issue駆動開発）

### 正規コマンド

Issue と PR の作成は、原則として以下のヘルパーを使います。

```bash
# Issue
./scripts/github/create-issue-with-labels.sh ...

# PR
./scripts/github/create-pr-with-labels.sh ...
```

### 1. Issue作成

新しい機能追加やバグ修正は、必ずIssueから始めます。
軽運用でもIssueは必須です。ただし簡潔で構いません。

```bash
./scripts/github/create-issue-with-labels.sh \
  --title "[Infra] 短い要約" \
  --body-file docs/issue-templates/feature_request.md \
  --type type:feature \
  --area area:infra \
  --risk risk:low \
  --cost cost:none
```

CLI からの Issue 作成は、必須ラベルの付け忘れを防ぐため、原則として上記ヘルパーを使います。

**Issueテンプレート**:
- `.github/ISSUE_TEMPLATE/feature_request.yml` (Web UI用)
- `docs/issue-templates/feature_request.md` (CLI用 `--body-file`)

**Issueタイトル命名規則**:
- `Issue: [Type] 短い要約`

**軽運用のIssueに必要な最小項目**:
- `目的`
- `対象`
- `受け入れ条件`

見出し階層は固定しませんが、上記3項目を本文に含めてください。

**Issue必須ラベル4種類**:
- `type:*` - ちょうど1つ
- `area:*` - 1つ以上、複数可
- `risk:*` - ちょうど1つ
- `cost:*` - ちょうど1つ

CLI / API / AI Agent からIssueを作ること自体は許容します。
ただし、起票後に GitHub Actions が本文とラベルを検査し、不備があれば `needs-template` を付けます。
`needs-template` が付いたIssueは、着手やPR作成の対象にしません。

AI Agent を使う場合は、いきなり起票せずに先に Issue プランを提示し、人間が確認してから起票します。
Issue プランには、少なくともタイトル案、`目的`、`対象`、`受け入れ条件`、推奨ラベルとしての `type/area/risk/cost`、`使用ヘルパー: ./scripts/github/create-issue-with-labels.sh` を明示して含めてください。

---

### 2. ブランチ作成

Issueに基づいてブランチを作成します。

```bash
# ブランチ命名規則: <issue番号>-<kebab-case要約>
git checkout -b 38-update-readme
```

**例**:
```bash
# Issue #38: README更新
git checkout -b 38-update-readme
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
git push -u origin 38-update-readme
```

---

### 5. Pull Request作成

PRテンプレートを使ってPRを作成します。

**PowerShell推奨例**:
```powershell
./scripts/github/create-pr-with-labels.sh `
  --title "docs: update contributing guide" `
  --body-file .github/pull_request_template.md `
  --issue XX `
  --type type:feature `
  --area area:backend `
  --risk risk:low `
  --cost cost:none `
  --base main
```

**bash/zsh例**:
```bash
./scripts/github/create-pr-with-labels.sh \
  --title "docs: update contributing guide" \
  --body-file .github/pull_request_template.md \
  --issue XX \
  --type type:feature \
  --area area:backend \
  --risk risk:low \
  --cost cost:none \
  --base main
```

CLI からの PR 作成は、必須ラベルの付け忘れを防ぐため、原則として上記ヘルパーを使います。
このヘルパーは `Closes #<issue番号>` を PR 本文へ自動で追記します。

**PRタイトル命名規則**:
- `PR: <type>: <変更の要約>`

AI Agent を使う場合は、PR もいきなり作成せず、先に PR プランを提示して人間が確認してから作成します。
PR プランには、少なくともタイトル案、`目的`、`変更内容`、`影響範囲`、`Closes/Fixes/Refs #<issue番号>`、推奨ラベルとしての `type/area/risk/cost`、`使用ヘルパー: ./scripts/github/create-pr-with-labels.sh` を明示して含めてください。

**PR本文のIssueリンク規則**:
- `Closes #<issue番号>`
- `Fixes #<issue番号>`
- `Refs #<issue番号>`

上記のいずれかを必ず記載してください。PR Check が確認します。

**PRテンプレート項目** (`.github/pull_request_template.md`):
- 目的
- 変更内容
- 影響範囲
- 可観測性/検証
- ロールバック手順
- `Closes #XX` （Issue自動クローズ）

**全PRで必須にするもの**:
- `Closes/Fixes/Refs #<issue番号>`
- `type:*` - ちょうど1つ
- `area:*` - 1つ以上、複数可
- `risk:*` - ちょうど1つ
- `cost:*` - ちょうど1つ

**全PRで推奨にするもの**:
- `目的`
- `変更内容`
- `影響範囲`

**厳密運用のPR**:
- 次のいずれかに当てはまる場合は厳密運用として扱います
  - `risk:medium/high`
  - `cost:medium/large`
  - `terraform/**`
  - `.github/workflows/**`
  - `scripts/deployment/**`
  - `scripts/validation/**`
- `ロールバック` は厳密運用PRで必須です
- GitHub の `Approve 1` は必須にしませんが、人間が丁寧に確認します

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
git switch main
git pull origin main
```

#### ローカル作業ブランチの整理

PRをマージしたら、ローカルも `main` に戻して最新化します。

```bash
git switch main
git pull origin main
```

不要になったローカル作業ブランチは削除して構いません。

```bash
git branch -d XX-description
```

---

### 7. 次のIssueへ

mainブランチから次のIssue用ブランチを作成します。

```bash
./scripts/github/create-issue-with-labels.sh \
  --title "[Type] 次のタスク" \
  --body-file docs/issue-templates/feature_request.md \
  --type type:docs \
  --area area:docs \
  --risk risk:low \
  --cost cost:none
git checkout -b YY-next-task
```

---

## 🧭 運用モード

### 軽運用

以下のような変更は軽運用で進めます。

- `README`
- `docs`
- コメント修正
- 文言修正
- 影響範囲が限定的な軽微修正

軽運用でも `Issue -> Branch -> PR -> CI` の流れは維持します。

### 厳密運用

以下のいずれかに該当する変更は厳密運用で進めます。

- `terraform/`
- `.github/workflows/`
- `IAM`
- `Secrets`
- `Network`
- `Security`
- `deploy`
- `destroy`
- 運用環境に影響する変更
- コスト影響がある変更
- ロールバックを考える必要がある変更

厳密運用では、Issue と PR の記載を丁寧に行い、人間が変更内容を十分に確認します。

### 例外ルール

- 緊急時でも `Blank issue` には頼らず、既存フォームまたはCLI/AI下書きから起票する
- 緊急時でも PR は必ず作る
- `main` へ直pushはしない

---

## 📋 開発フロー図

```
┌─────────────────────────────────────────────┐
│ 1. Issue作成                                 │
│    ./scripts/github/create-issue-with-labels.sh ... │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 2. ブランチ作成                              │
│    git checkout -b XX-description            │
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
│    git push -u origin XX-description         │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 5. PR作成                                    │
│    ./scripts/github/create-pr-with-labels.sh ... │
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
- [ ] ブランチ名が `<issue番号>-<kebab-case要約>` 形式か
- [ ] コミットメッセージがConventional Commits形式か
- [ ] PR本文に `Closes #XX` / `Fixes #XX` / `Refs #XX` のいずれかを記載したか

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
./scripts/github/create-issue-with-labels.sh \
  --title "[Question] 質問内容" \
  --body-file docs/issue-templates/feature_request.md \
  --type type:docs \
  --area area:docs \
  --risk risk:low \
  --cost cost:none
```

---

**最終更新**: 2025年10月10日
