# 0023. ローカルツール管理に mise を採用し terraform-docs は pre-commit で運用する

## ステータス

Accepted

## 日付

2026-06-27

## 決定内容

ローカル開発で使う主要ツールのバージョン管理に `.mise.toml` を採用する。

`.mise.toml` は、開発者のローカル環境で次のツールを揃えるための正本とする。

- Terraform
- Node.js
- pre-commit
- terraform-docs
- TFLint

Terraform のローカルバージョン pin は `.mise.toml` に集約し、既存の `.terraform-version` は削除する。

Terraform root module の README は `.terraform-docs.yml` と pre-commit の `terraform_docs` hook で生成・更新する。
対象は `terraform/modules/*` を除く first-level root module とし、現時点では `terraform/foundation`、`terraform/network`、`terraform/database`、`terraform/service`、`terraform/cdn` が該当する。
`terraform/modules/*` は今回の scope から外す。

CI/CD workflow の Terraform / TFLint / Node.js version は、当面 `.github/workflows/*.yml` の明示 pin を維持する。
`.mise.toml` はローカル開発ツールの再現性を担い、PR / deploy / destroy workflow は workflow 内の pin で実行環境を固定する。

terraform-docs の CI 差分チェックは今回追加せず、pre-commit によるローカル更新に留める。
CI gate 化が必要になった場合は、実行時間、false positive、既存 PR gate への影響を確認したうえで別 Issue で判断する。

## 背景

これまで Terraform は `.terraform-version` で version を示していたが、Node.js、pre-commit、terraform-docs、TFLint は同じ入口で再現できなかった。
Terraform root module の inputs / outputs / resources の README も手動管理または未整備であり、Terraform 変更時にドキュメントが drift しやすい状態だった。

Issue #427 では、ローカル開発環境のツールバージョンを 1 つのファイルに集約し、terraform-docs で root module README を維持できる状態を目標にした。

一方で、CI/CD workflow は PR gate と deploy / destroy 実行環境の再現性を担っている。
`.mise.toml` を導入しても、workflow 側の version pin を即座に削除すると、GitHub Actions 上で使う action や cache、setup step の責務が曖昧になる。
そのため、今回の PR ではローカルツールの正本を `.mise.toml` に置き、CI/CD workflow の version pin は明示的に残す。

## 検討した選択肢

### `.terraform-version` と個別インストール手順を維持する

- 長所: 既存利用者への変更が最小限で済む
- 長所: tfenv / tenv など `.terraform-version` を読むツールと相性がよい
- 短所: Terraform 以外の Node.js、pre-commit、terraform-docs、TFLint を同じ入口で揃えられない
- 短所: Terraform version を `.terraform-version` と `.mise.toml` の二重管理にすると更新漏れが起きやすい

### asdf を採用する

- 長所: 複数言語・ツールの version 管理として広く使われている
- 短所: plugin 導入手順がツールごとに増えやすい
- 短所: この repository では mise の `.mise.toml` だけで必要なツールを表現できるため、追加の運用メリットが小さい

### Homebrew / 手順書ベースで管理する

- 長所: macOS では導入しやすい
- 短所: Linux / CI / WSL との再現性が落ちる
- 短所: version pin が手順書依存になり、実際のローカル環境と drift しやすい

### `.mise.toml` を採用し、CI/CD workflow も即座に `.mise.toml` から読む

- 長所: version source を完全に一本化できる
- 長所: ローカルと CI の drift を機械的に減らせる
- 短所: workflow の setup 手順が変わり、PR gate / deploy / destroy の実行経路に影響する
- 短所: Terraform / TFLint / Node.js の setup action と mise 実行の責務分担を別途設計する必要がある
- 短所: 今回の目的であるローカル開発ツール整備より scope が広がる

### `.mise.toml` をローカル正本として採用し、CI/CD workflow は明示 pin を維持する（採択）

- 長所: ローカル環境の再現性を改善しつつ、CI/CD 実行経路を変えない
- 長所: `.terraform-version` を削除することで Terraform のローカル pin 二重管理を避けられる
- 長所: workflow 側の version pin 見直しを、必要になった段階で独立した Issue として扱える
- 短所: `.mise.toml` と workflow pin の間に version drift が起きる可能性が残る
- 短所: version 更新時は `.mise.toml` と workflow の両方を review 対象として意識する必要がある

### terraform-docs を CI required check にする

- 長所: README drift を CI で確実に検出できる
- 長所: pre-commit 未導入の開発者でも PR で漏れに気づける
- 短所: 初期導入時点で PR gate が増え、軽微な Terraform 変更の待ち時間と failure point が増える
- 短所: 生成対象や modules 配下の扱いが固まる前に blocking gate 化すると、運用調整のたびに CI 変更が必要になる

### terraform-docs は pre-commit のみに留める（採択）

- 長所: README 生成をローカルの編集 workflow に寄せられる
- 長所: 初期導入時の CI 影響を最小化できる
- 長所: CI gate 化の価値を、実運用で drift が問題になってから判断できる
- 短所: pre-commit を実行しない場合、README drift が PR 上で自動検出されない

## 採択理由

Issue #427 の主目的は、ローカル開発ツールと Terraform root module README の整備である。
`.mise.toml` は Terraform だけでなく Node.js、pre-commit、terraform-docs、TFLint を同じ入口で揃えられるため、この目的に合う。

`.terraform-version` を残すと Terraform version の更新点が増えるため、ローカルの Terraform pin は `.mise.toml` へ集約する。

CI/CD workflow は PR gate と deploy / destroy の実行経路であり、ローカルツール管理とは責務が異なる。
今回 workflow の setup 方式まで変えると変更範囲が広がるため、workflow 内の明示 pin は維持する。
drift リスクは残るが、version 更新時に `.mise.toml` と workflow pin を一緒に確認する運用で扱い、完全な一本化は必要性が高まった段階で再検討する。

terraform-docs の CI gate 化も同様に、初期導入 PR では見送る。
pre-commit で root module README を生成できる状態を先に作り、CI required 化は drift の発生状況や実行コストを見て別途判断する。

## 影響

- 開発者は `mise install` でローカル主要ツールを揃えられる
- `pre-commit install` 後、Terraform root module の README は `terraform_docs` hook で更新される
- `.terraform-version` は削除され、Terraform のローカル version pin は `.mise.toml` に集約される
- CI/CD workflow の Terraform / TFLint / Node.js version pin は残る
- CI では terraform-docs drift をまだ検出しない
- version 更新 PR では `.mise.toml` と `.github/workflows/*.yml` の pin の関係を review する必要がある

## 関連

- [Issue #427](https://github.com/kmryst/terraform-hannibal/issues/427)
- [Quality Gates](../operations/quality-gates.md)
- [Terraform Modules Architecture](../architecture/terraform-modules.md)
- [CONTRIBUTING.md](../../CONTRIBUTING.md)
