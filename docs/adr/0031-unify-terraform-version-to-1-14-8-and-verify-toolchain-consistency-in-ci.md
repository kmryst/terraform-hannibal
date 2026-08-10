# 0031. Terraform を 1.14.8 に統一し、ローカル正本と CI pin の整合性を CI で検査する

## ステータス

Accepted

## 日付

2026-08-10

## 決定内容

本リポジトリの Terraform CLI バージョンを **1.14.8** に統一する。統一先の値と検査方式は 3 リポジトリ共通標準である `kmryst/idp-golden-path` の ADR 0014 に従い、本リポジトリはその消費側として適用する。

- `.mise.toml` の `[tools] terraform` を `1.14.8` にする。ローカル実行環境のツールチェーンバージョンの正本は引き続き `.mise.toml`（ADR 0023 の決定を維持）
- CI（GitHub Actions）は `.mise.toml` を読まず workflow 内で明示 pin する（ADR 0023 の決定を維持）。pin の値は `.mise.toml` の宣言と一致させる
- Terraform バージョンの更新点を **`env.TERRAFORM_VERSION` の 1 箇所に集約**する。`pr-check.yml` の `hashicorp/setup-terraform` に直書きされていた `terraform_version: 1.12.1` は `${{ env.TERRAFORM_VERSION }}` の参照に変更する。`deploy.yml` / `destroy.yml` は既に env 参照であり、これで 3 workflow の形が揃う
- 宣言と pin の一致は人間の注意力に任せず、`kmryst/idp-golden-path/.github/workflows/toolchain-version-check.yml@v1` を消費する caller workflow で **PR ごとに機械検査**する
- 新規ガードレールのため、branch protection の required status checks には即座には追加しない（段階的 required 化の方針は [ADR 0013](./0013-promote-quality-checks-to-required-gradually.md) に従う）

root module の `required_version` は `>= 1.11.0` のまま変更しない。1.14 系だけが必要な機能を使っていないため、宣言上の機能下限を実行環境の pin に合わせて引き上げる理由がない（[docs/terraform-environments.md](../terraform-environments.md)）。

## 背景

### drift が現実化していた

[ADR 0023](./0023-adopt-mise-for-local-tooling-and-pre-commit-terraform-docs.md) は「`.mise.toml` をローカル正本とし、CI/CD workflow は明示 pin を維持する」を採択し、その短所として「`.mise.toml` と workflow pin の間に version drift が起きる可能性が残る」ことを明記していた。2026-08-10 の実測で、**このリスクが既に現実化していた**ことが判明した。

- `.mise.toml` は Terraform `1.12.1` を宣言していたが、**mise 自体が導入されておらず宣言に強制力がなかった**
- 実際のローカル実行では apt でインストールされた Terraform `1.14.8` が使われていた
- その結果 `terraform/foundation` の state（実リソース 57 件）が `1.14.8` に上がっていた

ADR 0023 が想定していた「version 更新時に `.mise.toml` と workflow pin を一緒に確認する運用」は、宣言そのものが実行環境に効いていない状況では機能しない。drift の検知手段がなかったため、誰も気付けなかった。

### 更新経路が失われていた層

Terraform の state は前方互換がなく、記録された `terraform_version` より古い CLI での操作を拒否する。`terraform/foundation` は原則として人間が手動 apply する層であり（[CLAUDE.md](../../CLAUDE.md)）、CI の deploy/destroy 対象ではない。

- `foundation` の state: `1.14.8`
- CI の pin（`pr-check.yml` / `deploy.yml` / `destroy.yml`）: `1.12.1`
- `.mise.toml` の宣言: `1.12.1`

つまり、宣言どおりに `1.12.1` を使うと `foundation` を操作できない。実リソース 57 件を抱えたまま、正規の手順からは更新できない層が成立していた。

一方、CI が触る 5 層（network / database / service / cdn / observability）は state の `terraform_version` が `1.12.1` で、いずれもリソース 0 件（destroy 済み）だった。これらは次回 apply 時に `1.14.8` へ上がるだけで、実リソースへの影響はない。

### 3 リポジトリ横断の分裂

同じ実測で `idp-golden-path` / `ticket-c2c-platform` を含む 3 リポジトリの state 13 件を調べたところ、実リソースを持つ state は既に `1.14.8` に上がっており、`1.12.1` はリソース 0 件の層にしか残っていなかった。層ごとにバージョンが割れているのは設計判断ではなく、CI 経由で実行したか手動で実行したかによってたまたま使われた CLI が違っただけの事故である。

この分裂の解消方針を 3 リポジトリ標準として定めたのが `idp-golden-path` の ADR 0014 であり、本 ADR はその消費側としての適用判断を記録する。

## 検討した選択肢

### 案 A: 1.12.1 に揃える（`.mise.toml` の宣言を実効値とする）

CI pin を一切変えずに済み、これまでの CI 実行実績（1.12.1）をそのまま踏襲できる。

しかし `foundation` の state が既に `1.14.8` で記録されており、前方非互換のため `1.12.1` では操作できない。実行するには state ファイル内の `terraform_version` を手で書き換える必要があり、実リソース 57 件を抱えた state に対する手動編集は復旧不能な破壊のリスクを伴う。「バージョンを揃える」という可逆な作業のために不可逆な破壊リスクを取ることになるため却下した。

### 案 B: 層ごと・リポジトリごとに異なるバージョンを許容する

現状をそのまま追認するため移行コストはゼロになる。

しかし `foundation` の更新経路が無いという実害が解消しない。さらに、どのバージョンが「意図された値」なのか定義されないままなので、drift の検査基準そのものが作れない。事故を仕様に格上げするだけであり却下した。

### 案 C: 1.14.8 に統一するが、検査は入れず運用注意に留める

ADR 0023 と同じ「更新時に両方を見る」運用を継続する案。変更範囲が最小で、CI の job も増えない。

しかし今回の事故は、まさにその運用が機能しないことを実証している。値だけを揃えても、次に片方だけを更新した時点で同じ状態に戻る。今回の本質はバージョンの値ではなく**宣言と実効値の乖離を誰も検知できなかったこと**にあるため却下した。

### 案 D: CI から `.mise.toml` を直接読み、二重管理そのものを廃止する

version source を完全に一本化でき、drift が原理的に発生しなくなる。

しかし CI に mise のインストール手順を持ち込むと、`hashicorp/setup-terraform` / `actions/setup-node` のキャッシュと実行実績を捨てることになる。ADR 0023 が同じ理由でこの案を見送っており、今回それを覆すだけの新しい根拠はない。二重管理の唯一の欠点である drift を検査で潰せるなら、こちらの方が安価である。

### 案 E（採択）: 1.14.8 に統一し、整合性を reusable workflow で機械検査する

`.mise.toml` をローカル正本、CI pin をその写像とする ADR 0023 の構造を維持したまま、両者の一致を CI で検査する。検査ロジックは `idp-golden-path` から reusable workflow として配布されているものを `@v1` で消費し、本リポジトリには薄い caller のみを置く。

## 採択理由

- state の前方非互換という制約が選択肢を実質的に一つに絞っている。1.14.8 は「良いから選んだ」のではなく、**実リソースを持つ state が既にそこにいるから、そこしか行き場がない**（案 A の却下理由）
- ADR 0023 の構造（ローカル正本 + CI 明示 pin）自体は誤っていなかった。欠けていたのは検知手段だけであり、構造を作り替える案 D より、短所を潰す案 E の方が変更範囲に対する効果が大きい
- 案 C を採らないのは、ADR 0023 が既に「運用で気を付ける」を試して失敗しているため。同じ対策を再掲しても再発を防げない
- 検査ロジックを本リポジトリに実装せず reusable workflow を消費するのは、3 リポジトリに同じロジックをコピーすると必ず乖離するため。CI ガードレールの共通化方針（[github-flow-guardrails.md](../operations/github-flow-guardrails.md)）と一致する
- `pr-check.yml` の直書きを `${{ env.TERRAFORM_VERSION }}` に変えるのは、更新点を 1 箇所に集約するため。同一ファイル内に更新点が 2 つあると、片方だけ直す事故が起きる。検査器は式による間接参照を pin とみなさないため、この変更で検査対象は env 定義 3 箇所に絞られ、検査の意味も明確になる

## 影響

- `.mise.toml` の Terraform 宣言が `1.14.8` になる。`mise install` 済みの環境では `terraform` コマンドがそのまま 1.14.8 を解決する
- `pr-check.yml` / `deploy.yml` / `destroy.yml` の `TERRAFORM_VERSION` が `1.14.8` になる。今後の Terraform バージョン更新は `.mise.toml` と各 workflow の `env` の計 4 箇所を同時に変更する（不一致は CI が検出する）
- `pr-check.yml` の `setup-terraform` は `${{ env.TERRAFORM_VERSION }}` を参照するようになり、同一ファイル内の更新点が 1 つになる
- PR ごとに `toolchain-version-check / Toolchain Version Check` の check run が作成される。Dependabot PR も免除しない
- CI が触る 5 層（network / database / service / cdn / observability）の state は、次回 apply 時に `terraform_version` が `1.14.8` へ上がる。いずれも現時点でリソース 0 件のため実リソースへの影響はない
- `foundation` 層は、ローカル CLI が 1.14.8 になることで **更新経路が回復する**。これが本変更の実質的な効果である
- 一度 1.14.8 で apply した state は 1.12.1 の CLI で操作できなくなる。ロールバックはこの PR をマージし apply する前に限り無害である
- 全 6 root module が Terraform 1.14.8 で `fmt -check -recursive` / `init -backend=false` / `validate` を通ることをローカルで実測確認した。`fmt -check` の結果は 1.12.1 と 1.14.8 で同一（どちらも差分なし）、deprecation warning は 0 件、`.terraform.lock.hcl` の変更も発生しなかった
- 検査対象は Terraform のみである。TFLint は `.mise.toml`（`0.62.1`）と `pr-check.yml`（`v0.62.1`）が一致しているが検査されない。Node.js は `.mise.toml` が `24.18.0`、workflow が major のみの `24` で粒度が異なるため、そもそも一致検査になじまない

## 再検討条件

- **Terraform の新しいメジャーバージョンが出た場合**（2.x など）。state 互換性・provider 互換性・setup アクションの対応状況を確認し、統一先を更新するか判断する
- **1.14.8 に固有の不具合が判明した場合**。移行先は 1.14.x の patch 上位であり、ダウングレードではない（前方非互換の制約は変わらない）
- **CI が mise を直接使う構成へ移行した場合**（案 D）。ローカル正本と CI pin の二重管理そのものが不要になり、本 ADR の検査も役目を終える
- **`.mise.toml` 以外のツールチェーン宣言方式へ移行した場合**（`.tool-versions` / devcontainer / Nix など）。検査器のパーサを差し替える必要がある
- **TFLint / Node.js も検査対象に加えたくなった場合**。reusable workflow 側の拡張として `idp-golden-path` で判断する

## 関連

- [Issue #591](https://github.com/kmryst/terraform-hannibal/issues/591)
- [ADR 0013. 品質チェックを観察期間後に段階的 required 化する](./0013-promote-quality-checks-to-required-gradually.md)
- [ADR 0023. ローカルツール管理に mise を採用し terraform-docs は pre-commit で運用する](./0023-adopt-mise-for-local-tooling-and-pre-commit-terraform-docs.md) — 本 ADR は 0023 を supersede せず、0023 が短所として挙げていた version drift リスクに検知手段を追加する
- kmryst/idp-golden-path ADR 0014（Terraform ツールチェーンのバージョンを 3 リポジトリで 1.14.8 に統一し、ローカル正本と CI pin の整合性を CI で検査する）— 統一先バージョンと検査契約の正本
- [Terraform 環境分離設計](../terraform-environments.md)
- [GitHub Flow Guardrails](../operations/github-flow-guardrails.md)
- [Terraform Docs: State — version compatibility](https://developer.hashicorp.com/terraform/language/state)
