# 🚨 絶対ルール: Issue駆動開発の徹底

**コード実装前に必ずGitHub Issueを作成または参照すること。**

### Issue / PR テンプレートの強制使用

❗ Issueは必ず既定のテンプレートを使用すること（Web UIのテンプレート選択、またはCLIの `--template` / `--body-file` を利用）。

- CLI例（feature request テンプレート）:

  ```bash
  gh issue create --template feature_request.md --label "type:docs,area:docs,risk:low,cost:none"
  ```

  CLI でテンプレ本文を扱う場合は `.github/tmp/` 配下に一時ファイルを作成し、起票後すぐ削除すること（例: `.github/tmp/issue-<summary>.md`）。
  
  **一時ファイル削除時の必須ルール:**
  - 削除理由を必ず明示すること（例: "Issue起票に使った一時ファイルを削除（CONTRIBUTINGガイドに従う）"）
  - `run_in_terminal` の `explanation` パラメータで理由を説明
  - ユーザーが意図を理解できるよう、何を削除するか・なぜ削除するかを明確に伝える

❗ Pull Request も必ずテンプレートを適用すること（Web UIでのテンプレート選択、またはCLIで `--body-file .github/pull_request_template.md` を指定）。

- PowerShell推奨例（Issue番号自動埋め込み）:

  ```powershell
  gh pr create --title "[Docs] 要約" `
    --body "$(Get-Content .github/pull_request_template.md -Raw)`n`nCloses #XX" `
    --label type:docs --label area:docs --label risk:low --label cost:none
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

## 🚀 開発ワークフロー（Issue駆動開発）

### 1. Issue作成（必須第一ステップ）

```bash
gh issue create --template feature_request.yml \
  --label "type:feature,area:backend,risk:low,cost:none"
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
gh pr create --title "[Feature] 要約" `
  --body "$(Get-Content .github/pull_request_template.md -Raw)`n`nCloses #XX" `
  --label type:feature --label area:backend --label risk:low --label cost:none
```

### 4. マージ & 自動クリーンアップ

```bash
# 推奨: GitHub CLI Alias
gh done XX

# Alias設定方法
gh alias set done '!f() { gh pr merge "$1" --merge && git checkout main && git pull origin main; }; f'
```

---
