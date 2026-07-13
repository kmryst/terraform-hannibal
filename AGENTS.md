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

## 設計文書の更新と設計判断の記録 (ADR)

実装によって仕様・構成・運用手順が変わった場合は、まず該当領域の正本を更新します。
実装時は、仕様・構成・運用手順に加えて、監視・アラート・runbook・CI/CD・セキュリティ・コスト・利用者向け手順への docs 影響を必ず確認します。
影響がある場合は、同じ PR で該当領域の正本を更新します。正本がない場合に限り、最小限の docs を新規作成します。
影響がない場合は、不要な docs を増やしません。

現在の仕様・構成・運用手順は、領域ごとに定められた正本に従います。
ADR はその正本を置き換えるものではなく、重要な設計判断の背景・採択理由・トレードオフ・再検討条件を記録するものです。

トレードオフを伴う設計判断は `docs/adr/` に ADR (Architecture Decision Record) として残します。ADR には決定内容に加えて、検討した代替案とそのトレードオフ（なぜ他の案ではなくその選択にしたか）を記載します。採番・形式・ステータスの正本は `docs/adr/README.md` に従います（番号は ADR を追加する PR の時点で確定し、Issue / ブランチ段階では予約しません）。ADR で判断が変わった場合は、影響する領域の正本も同じ PR で更新します。

## コミットメッセージ

コミットを作成する場合は、必ず `CONTRIBUTING.md` の Conventional Commits / commitlint ルールに従います。
独自判断で `wip`、`fix` のみ、`update files` のような曖昧なコミットメッセージを使ってはいけません。

PR 作成前には、対象コミットと PR title が commitlint を通ることを確認します。
許可 type や形式など、詳細ルールの正本は `CONTRIBUTING.md` とします。

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

`--body-file` には `.github/pull_request_template.md` をそのまま渡さず、テンプレートを埋めたコピーを別ファイルとして作成して渡します。
テンプレートをそのまま渡すと、未記入のプレースホルダ本文の末尾に helper が追記する `Closes #<issue番号>` が重複した、壊れた PR になります。

```bash
./scripts/github/create-pr-with-labels.sh \
  --title "docs: title" \
  --body-file /path/to/filled-pr-body.md \
  --issue <issue番号> \
  --type type:docs \
  --area area:docs \
  --risk risk:low \
  --cost cost:none \
  --base main \
  --head <branch>
```

## Terraform 変更時の追加確認

### 実行してよい検証コマンド

```bash
# フォーマットチェック（差分なしが正常）
terraform fmt -check -recursive

# 静的バリデーション（AWS 認証不要）
for dir in terraform/foundation terraform/network terraform/database terraform/service terraform/cdn; do
  terraform -chdir="$dir" init -backend=false
  terraform -chdir="$dir" validate
done
```

### ディレクトリ別の方針

| ディレクトリ | 用途 | apply/destroy |
|---|---|---|
| `terraform/foundation/` | 基盤 IAM・OIDC 等（恒久リソース） | PR マージ後に人間が手動実行。`state rm` しない |
| `terraform/network/` | VPC・subnet・Security Group | `deploy.yml` / `destroy.yml` から実行 |
| `terraform/database/` | RDS PostgreSQL | `deploy.yml` / `destroy.yml` から実行 |
| `terraform/service/` | ECS・ALB・CodeDeploy・monitoring | `deploy.yml` / `destroy.yml` から実行 |
| `terraform/cdn/` | CloudFront・S3・DNS | `deploy.yml` / `destroy.yml` から実行 |

### state 管理方針

- `terraform/foundation/` の新規リソースは state に残して継続管理する
- `terraform state rm` は原則行わない
- `terraform/network/`、`terraform/database/`、`terraform/service/`、`terraform/cdn/` のリソースは deploy/destroy で自動管理される

## 禁止事項

次は、ユーザーから明示された場合でも実行前に確認します。

- `terraform apply` / `terraform destroy`
- `terraform state rm`
- AWS リソースを変更する CLI 操作
- `git push --force` / `main` への direct push
- GitHub Issue / PR の無断編集・無断作成
- secret / credential 値の出力
- `.env` ファイルのコミット
