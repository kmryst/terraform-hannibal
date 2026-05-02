# CLAUDE.md — terraform-hannibal 作業ルール

このファイルは Claude Code が terraform-hannibal で作業を開始する前に自動的に読み込まれます。
一般論ではなく、このリポジトリ固有のルールに従って作業してください。

## 作業開始前に必ず読むファイル

1. **CONTRIBUTING.md** — ブランチ命名・Conventional Commits・PR 作成・ラベル体系・厳密運用定義
2. **docs/operations/github-flow-guardrails.md** — 軽運用/厳密運用の判断基準・Terraform plan 方針
3. **対象 Issue** — `gh issue view <issue番号>` で目的・受け入れ条件を確認する
4. **変更対象ファイル** — 実装前に現在の状態を Read ツールで確認する

## 作業内容別に追加で読むファイル

以下は該当する作業を始める前に読む。毎回すべてを読む必要はないが、判断に使う正本を優先する。

| 条件 | 読むファイル |
|---|---|
| Issue 起票 | `docs/issue-templates/feature_request.md` / `.github/ISSUE_TEMPLATE/feature_request.yml` |
| PR 作成 | `.github/pull_request_template.md` |
| ラベル判断 | `.github/labels.yml` |
| IAM / OIDC / Permission Boundary / PR Terraform plan Role の変更 | `docs/operations/iam-management.md`。PR Terraform plan Role は追加で `docs/operations/pr-terraform-plan-role-design.md` |
| scripts 配下のヘルパー利用・変更 | `scripts/README.md` と対象スクリプト |

`.github/copilot-instructions.md`、`.amazonq/rules/`、`.cursor/rules/` は各ツール向けの補助ルールであり、Claude Code の正本にはしない。
内容が衝突する場合は、`CONTRIBUTING.md` を運用ルールの正本として優先し、次に `docs/operations/github-flow-guardrails.md`、この `CLAUDE.md` の順で確認する。
ラベルは `.github/labels.yml`、IAM Role 一覧は `docs/operations/iam-management.md` など、個別領域の正本が明記されている場合はその正本に従う。

## 開発フロー

Issue 駆動開発を必ず守る。順序: Issue 確認 → ブランチ作成 → 実装 → コミット前停止 → コミット → Push → PR → Merge → Cleanup。

### ブランチ命名

```
<issue番号>-<kebab-case要約>
例: 127-pr-terraform-plan-role
```

### Issue 作成

Issue は起票前にプランを提示してユーザーに確認してもらう。
Issue 作成前プランには、タイトル案、目的、対象、受け入れ条件、推奨ラベル、使用ヘルパー、軽運用 / 厳密運用の判定と理由を明示する。
Issue 本文には専用の運用区分欄を追加しない。

```bash
./scripts/github/create-issue-with-labels.sh \
  --title "タイトル" \
  --body-file docs/issue-templates/feature_request.md \
  --type type:infra \
  --area area:infra \
  --risk risk:low \
  --cost cost:none
```

### PR 作成

PR は作成前にプランを提示してユーザーに確認してもらう。

```bash
./scripts/github/create-pr-with-labels.sh \
  --title "type: タイトル" \
  --body-file .github/pull_request_template.md \
  --issue <issue番号> \
  --type type:infra \
  --area area:infra \
  --risk risk:medium \
  --cost cost:none \
  --base main \
  --head <branch>
```

PR 作成前プランには、タイトル案、目的、変更内容、影響範囲、`Closes/Fixes/Refs #<issue番号>`、推奨ラベル、使用ヘルパー、軽運用 / 厳密運用の判定と理由、厳密運用の場合は `ロールバック` が必須かどうかを明示する。

### マージ後の cleanup

PR がマージされた後、次の Issue へ進む前に必ず実行する。
このヘルパーで `main` への切り替え、`git pull --ff-only`、マージ済み作業ブランチの整理を行う。

```bash
./scripts/github/cleanup-merged-pr-branch.sh <PR番号>
```

## PR 必須ラベル（4種類）

| ラベル | 要件 |
|---|---|
| `type:*` | ちょうど 1 つ |
| `area:*` | 1 つ以上（複数可） |
| `risk:*` | ちょうど 1 つ |
| `cost:*` | ちょうど 1 つ |

PR 本文には `Closes #<issue番号>` / `Fixes #<issue番号>` / `Refs #<issue番号>` のいずれかを必須で含める。
`create-pr-with-labels.sh` は `Closes #<issue番号>` を自動で追記する。

## 厳密運用に該当する変更

以下のいずれかに該当する変更は厳密運用。PR 本文の `ロールバック` セクションに実質的な内容が必須になる。

- `terraform/**` 配下の変更
- `.github/workflows/**` 配下の変更
- `scripts/deployment/**` 配下の変更
- `scripts/validation/**` 配下の変更
- IAM / OIDC / Permission Boundary の変更
- Secrets / Network / Security の変更
- deploy / destroy に関わる変更
- 運用環境に影響する変更
- コスト影響がある変更
- ロールバックを考える必要がある変更
- `risk:medium` / `risk:high` ラベルの PR
- `cost:medium` / `cost:large` ラベルの PR

## Terraform 変更時の追加確認

### 実行してよい検証コマンド

```bash
# フォーマットチェック（差分なしが正常）
terraform fmt -check -recursive

# 静的バリデーション（AWS 認証不要）
terraform -chdir=terraform/foundation init -backend=false
terraform -chdir=terraform/foundation validate

terraform -chdir=terraform/environments/dev init -backend=false
terraform -chdir=terraform/environments/dev validate
```

### ディレクトリ別の方針

| ディレクトリ | 用途 | apply/destroy |
|---|---|---|
| `terraform/foundation/` | 基盤 IAM・OIDC 等（恒久リソース） | PR マージ後に人間が手動実行。`state rm` しない |
| `terraform/environments/dev/` | アプリ全体インフラ（一時的） | `deploy.yml` / `destroy.yml` から実行 |

### state 管理方針

- `terraform/foundation/` の新規リソースは **state に残して継続管理する**
- `terraform state rm` は原則行わない
- `terraform/environments/dev/` のリソースは deploy/destroy で自動管理される

### IAM / OIDC 変更時

- Trust Policy の subject は最小限に絞る（ワイルドカード `*` を使わない）
- PR plan 用 Role は `pull_request` event 固定（`refs/heads/main` と混在させない）
- Permission Boundary の要否は設計文書 `docs/operations/pr-terraform-plan-role-design.md` を参照

### GitHub Actions 変更時

- `pull_request` vs `pull_request_target` を区別する（fork PR セキュリティに影響）
- OIDC 認証を使うジョブには `permissions: id-token: write` が必要
- fork PR では AWS Role を assume しない（workflow 側の `if` 条件で制御）

## 禁止事項

ユーザーから明示的に指示された場合でも、実行前に必ず確認する。

- `terraform apply` / `terraform destroy`
- `terraform state rm`
- AWS リソースを変更する CLI 操作（例: `aws iam create-role`）
- `git push --force` / `main` ブランチへの direct push
- GitHub Issue / PR の無断編集・無断作成
- secret / credential 値の出力
- `.env` ファイルのコミット

## ユーザー確認が必要な操作

以下は必ず事前にプランを提示し、ユーザーの確認を得てから実行する。

| 操作 | 確認のタイミング |
|---|---|
| Issue 起票 | 本文・ラベル案とコマンドを提示してから |
| コミット | コミット前サマリを提示して停止してから |
| git push | コミット確認後に明示的な許可を得てから |
| PR 作成 | タイトル・本文・ラベル・コマンド案を提示してから |
| ブランチ削除 | cleanup コマンド案を提示してから |
| terraform plan（AWS 認証が必要な場合） | 実行前にユーザーへ確認 |

## ラベル一覧

`.github/labels.yml` が正本。

| 種別 | 値 |
|---|---|
| type | `type:feature` / `type:bug` / `type:docs` / `type:infra` / `type:chore` / `type:refactor` / `type:test` |
| area | `area:frontend` / `area:backend` / `area:infra` / `area:ci-cd` / `area:docs` / `area:database` |
| risk | `risk:low` / `risk:medium` / `risk:high` |
| cost | `cost:none` / `cost:small` / `cost:medium` / `cost:large` |
