# AGENTS.md — terraform-hannibal Codex 作業ルール

このファイルは Codex が `terraform-hannibal` で作業する時の入口です。
共通運用ルールをこのファイルへ複製せず、正本を参照して作業してください。

## 役割分担

- `AGENTS.md`: Codex 向けの作業入口。このファイルを Codex の正本とする
- `CLAUDE.md`: Claude Code 向けの作業入口。Codex の正本にはしない
- `CONTRIBUTING.md`: Issue / Branch / PR / Label / 軽運用・厳密運用の共通正本
- `docs/operations/github-flow-guardrails.md`: GitHub フローの設計意図、未採用案、再検討条件
- `.github/labels.yml`: ラベル一覧の正本

内容が衝突する場合は、共通運用は `CONTRIBUTING.md` を優先し、設計意図は `docs/operations/github-flow-guardrails.md` を参照します。

## 作業開始前に読むもの

1. `CONTRIBUTING.md`
2. `docs/operations/github-flow-guardrails.md`
3. 対象 Issue (`gh issue view <issue番号>`)
4. 変更対象ファイル

作業内容に応じて、次の正本も読む。

| 条件 | 読むファイル |
|---|---|
| PR 作成 | `.github/pull_request_template.md` |
| ラベル判断 | `.github/labels.yml` |
| IAM / OIDC / Permission Boundary / PR Terraform plan Role の変更 | `docs/operations/iam-management.md` と `docs/operations/pr-terraform-plan-role-design.md` |
| scripts 配下のヘルパー利用・変更 | `scripts/README.md` と対象スクリプト |

## GitHub 運用ヘルパー

Codex は GitHub 操作を手作業で再現せず、既存ヘルパーを正規ルートとして使います。

| 操作 | 正規ヘルパー |
|---|---|
| Issue 作成 | `./scripts/github/create-issue-with-labels.sh` |
| PR 作成 | `./scripts/github/create-pr-with-labels.sh` |
| マージ後 cleanup | `./scripts/github/cleanup-merged-pr-branch.sh <PR番号>` |

Issue 作成と PR 作成は、実行前にユーザーへプランを提示して確認します。
Issue 本文には専用の運用区分欄を追加せず、起票前プランと PR 作成前プランで軽運用 / 厳密運用を判定します。

PR がマージされた後、次の Issue へ進む前に必ず `cleanup-merged-pr-branch.sh` を実行します。
このヘルパーは PR が `MERGED` であることを確認し、base branch を最新化してから作業ブランチを整理します。

## Issue 着手

新しい Issue に着手する時は、最新の `main` から作業ブランチを切ります。

```bash
git switch main
git pull --ff-only origin main
git switch -c <issue番号>-<kebab-case要約>
```

直前の PR をマージした後であれば、手動で同じ手順を再現せず、先に次を実行します。

```bash
./scripts/github/cleanup-merged-pr-branch.sh <PR番号>
```

## PR 作成前

PR 作成前プランには、少なくとも次を含めます。

- タイトル案
- 目的
- 変更内容
- 影響範囲
- `Closes/Fixes/Refs #<issue番号>`
- 推奨ラベル (`type / area / risk / cost`)
- 軽運用 / 厳密運用の判定と理由
- 厳密運用の場合、`ロールバック` が必須かどうか
- 使用ヘルパー: `./scripts/github/create-pr-with-labels.sh`

PR は原則として次のヘルパーで作成します。

```bash
./scripts/github/create-pr-with-labels.sh \
  --title "type: title" \
  --body-file .github/pull_request_template.md \
  --issue <issue番号> \
  --type type:docs \
  --area area:docs \
  --risk risk:low \
  --cost cost:none \
  --base main \
  --head <branch>
```

## 禁止事項

次は、ユーザーから明示された場合でも実行前に確認します。

- `terraform apply` / `terraform destroy`
- `terraform state rm`
- AWS リソースを変更する CLI 操作
- `git push --force` / `main` への direct push
- GitHub Issue / PR の無断編集・無断作成
- secret / credential 値の出力
- `.env` ファイルのコミット
