# 0032. 依存関係の自動更新を Dependabot に一本化し Renovate を採用しない

## ステータス

Accepted

## 日付

2026-08-16

## 決定内容

`terraform-hannibal` の依存関係自動更新は `.github/dependabot.yml`（Dependabot）を正とし、**Renovate を採用しない**。`renovate.json` は作成せず、Renovate GitHub App / セルフホスト runner も導入しない。

Dependabot でカバーできない対象（`variable "db_engine_version" { default = "15.14" }` のような、文字列として書かれた version）は、Renovate の `customManagers` ではなく専用の手段で扱う。手段の選定は [Issue #600](https://github.com/kmryst/terraform-hannibal/issues/600) で行う。

この ADR は Renovate の機能を否定するものではない。「いま Renovate を追加導入する理由が無い」という判断であり、下の「再検討条件」に該当したら見直す。

## 背景

[Issue #350](https://github.com/kmryst/terraform-hannibal/issues/350) は 2026-06-05 に「Renovate を導入し依存関係の自動更新を設定する」として起票され、2026-08-16 に「Dependabot に terraform ecosystem を追加し AWS provider の更新経路を作る」へ rescope された。起票から rescope までの間に、`terraform-hannibal` / `idp-golden-path` / `ticket-c2c-platform` の 3 リポジトリは Dependabot 前提の運用に揃っている。

起票時の問題意識そのものは正しかった。AWS provider が古いまま滞留し、`db_engine_version` の更新経路も無い。争点は「その痛みを Renovate で解くのか、Dependabot で解くのか」である。

`docs/operations/quality-gates.md` には「Renovate 導入を扱う #350 で管理します」という参照が 2 箇所残っており、#350 の rescope により現状と一致しなくなった。この ADR と同じ PR で修正する。

## 検討した選択肢

### Dependabot に一本化し Renovate を採用しない（採択）

- 長所: 既存の運用資産（grouping / ignore 規約 / 追跡 Issue / 見直し期限）をそのまま使える
- 長所: 3 リポジトリで同じ形が保たれ、横断の検索・棚卸しが成立し続ける
- 長所: 導入コストがゼロ
- 短所: 文字列で書かれた version（`db_engine_version`）を自動更新できない。別手段が必要になる

### Renovate に移行する

- 長所: `customManagers`（正規表現）で任意の文字列 version を依存関係として扱える
- 長所: Dependency Dashboard で更新状況を一覧できる
- 短所: 既存の Dependabot 運用資産（下記「根拠 2」）を全部書き直すことになる
- 短所: 3 リポジトリ同時移行が必要。移行期間中は形が揃わない

### Dependabot と Renovate を併用する

- 長所: それぞれの得意分野を使える
- 短所: **同じ依存に 2 つの bot が更新 PR を出して競合する。** 片方が上げた lockfile をもう片方が別の版で上書きし、PR が相互に stale になる
- 短所: ignore / grouping / 台帳を 2 系統で維持することになり、「どちらが正本か」が常に問われる

### Renovate を採用しないが、記録は #350 の Issue 本文に留める

- 長所: PR が不要
- 短所: Issue は close されると参照されにくい。再検討条件と「仮に採用する場合の形」が失われる
- 短所: `quality-gates.md` の古い参照はどのみち直す必要がある

## 採択理由

### 根拠 1 — 痛みの原因は実証済みの手段で解決できる

同一組織・同一 provider・同時点（2026-08-16）の比較。

| リポジトリ | `dependabot.yml` の terraform ecosystem | `.terraform.lock.hcl` の `hashicorp/aws` |
|---|---|---|
| `ticket-c2c-platform` | あり | **6.58.0**（bootstrap / dev / staging の 3 環境とも） |
| `terraform-hannibal` | **なし** | **6.8.0**（6 root module とも） |
| Terraform Registry の最新 | — | **6.60.0** |

`terraform-hannibal` が 50 minor 遅れているのは Dependabot の能力不足ではなく、**エントリを書いていないから**である。同じ Dependabot を同じ provider に対して使っている隣のリポジトリは最新の 2 minor 以内に追随している。ツールを替える前に、まだ使っていない機能を使う。

### 根拠 2 — 運用資産が Dependabot の形をしている

3 リポジトリ共通で、次が既に存在する。

| 資産 | 実体 |
|---|---|
| ignore の 7 項目コメント規約 | `.github/dependabot.yml` のコメントが「なぜ ignore しているか」の正本 |
| 追跡 Issue の OPEN 維持 + `dependabot-ignore` ラベル | 本リポジトリでは #542 / #551 / #555 / #564 |
| 見直し期限（デッドマンスイッチ） | 2026-11-02 に揃えてある |
| grouping 設定 | `github-actions` / `npm-dev` を first-match-wins 前提で配置 |
| 台帳 | `scripts/ci/dependabot-unblock.json` |
| 検査器 + テスト + fixture | `scripts/ci/dependabot-unblock-check.mjs` / `.test.mjs` / `scripts/ci/fixtures/` |
| 週次 workflow | `.github/workflows/dependency-unblock-check.yml`（reusable） |

このうち台帳・検査器・週次 workflow は `idp-golden-path`（実装本体）と `ticket-c2c-platform`（台帳 + caller）に存在し、**`terraform-hannibal` はまだ導入していない**（実測。本リポジトリの ignore は 7 項目コメント規約と追跡 Issue には従っているが、`scripts/ci/` 配下の台帳・検査器と caller workflow を持たない）。つまり本リポジトリは、この資産を捨てる側ではなく**これから受け取る側**であり、いま Renovate へ振ると受け取り先が消える。

これらは全て「Dependabot の `ignore` に何が入っているか」を前提に書かれている。Renovate へ移すなら、`ignore` に相当する `packageRules` の表現、台帳スキーマ、検査器の抽出器、fixture、docs をすべて作り直すことになる。得られるものは `customManagers` 1 機能である。

### 根拠 3 — 導入コスト

Renovate は GitHub App の導入かセルフホスト runner の運用、`renovate.json` の記述、Dependency Dashboard Issue の運用が増える。Dependabot は GitHub 内蔵で、追加の App も認可も要らない。

### Renovate にしかない利点（正直な評価）

`customManagers`（正規表現ベースの manager）により、`db_engine_version = "15.14"` のような **文字列で書かれた version** を依存関係として扱える。Dependabot にこれに相当する仕組みは無い。これは Renovate の明確な優位点である。

ただし本リポジトリで該当するのは **2 ファイルの 1 変数**（`terraform/database/variables.tf` と `terraform/modules/rds/variables.tf` の `db_engine_version`）だけである。そのために bot をもう 1 つ増やすのは割に合わない。さらに、Renovate が見るのは PostgreSQL の upstream リリースであって **AWS の RDS end of standard support date ではない**。RDS の minor は AWS 独自の EOL 日付を持つため（例: 15.14 は 2026-10-31）、AWS の情報と直接照合する専用チェックのほうが安く、かつ正確である。この選定は #600 で行う。

## 影響

- `renovate.json` は作成しない。Renovate GitHub App / セルフホスト runner も導入しない
- 依存関係更新の正本は `.github/dependabot.yml` とする
- `docs/operations/quality-gates.md` の「Renovate 導入を扱う #350 で管理します」「Renovate 導入時は〜検討します」を、Dependabot 前提の記述へ修正する（本 ADR と同じ PR）
- ADR 0017 / ADR 0025 に残る Renovate / #350 への言及は**書き換えない**。ADR は決定時点の記録であり、`docs/adr/README.md` の運用に従って古い ADR は削除も改変もせず、新しい ADR から参照する
- `docs/architecture/system-design.md` の `- **Renovate**: 自動依存関係更新` の修正は #350 の受け入れ条件に含まれるため、#350 で行う
- Dockerfile base image（`node:24-alpine`）と workflow 内 Docker image の tag / digest 更新は、Renovate の regex manager ではなく Dependabot の `docker` ecosystem か手動で扱う。どちらにするかは本 ADR の対象外
- `db_engine_version` の更新手段は #600 で決める

## 再検討条件

次のいずれかに該当したら、この判断を見直す。

1. **Dependabot でカバーできない「文字列で書かれた version」が複数箇所に増えたとき。** 現在は `db_engine_version` の 1 変数だけであり、専用チェックのほうが安い。対象が増えて個別チェックを何本も書くことになるなら、`customManagers` の汎用性が勝つ
2. **Dependabot の terraform ecosystem が実運用で期待どおり動かないと判明したとき。** 具体的には、version constraint だけを上げて `.terraform.lock.hcl` を更新しない、grouping が root module 間で効かない、といった挙動。**これは現時点で未検証**であり、#350 で実 PR により実測する
3. **3 リポジトリの Dependabot 運用資産（台帳・検査器・追跡 Issue・見直し期限）を作り直すコストを払う理由が生じたとき**

### 仮に採用する場合の形（参考）

Renovate の設定は reusable workflow ではなく各リポジトリの `renovate.json` に置く。したがって `idp-golden-path` が配るのは workflow ではなく**共有プリセット**になり、消費側は次の形で参照する。

```json
{
  "extends": ["github>kmryst/idp-golden-path"]
}
```

この `github>owner/name` という構文は Renovate 公式ドキュメント [Shareable Config Presets](https://docs.renovatebot.com/config-presets/) に記載されている形式である（2026-08-16 参照）。既存のゴールデンパス配布（reusable workflow を `idp-golden-path` から配る）と同じ構図になる。

ただし `idp-golden-path` に入れた時点でそれが「標準」になる。試すなら影響範囲の小さいリポジトリを先にし、golden path への昇格は実績が出てからにする。

## 関連

- [Issue #350](https://github.com/kmryst/terraform-hannibal/issues/350) - Dependabot に terraform ecosystem を追加し AWS provider の更新経路を作る（2026-08-16 に Renovate 導入から rescope）
- [Issue #600](https://github.com/kmryst/terraform-hannibal/issues/600) - RDS engine version の更新経路を決める（Dependabot 非対象）
- [Issue #601](https://github.com/kmryst/terraform-hannibal/issues/601) - 本 ADR と `quality-gates.md` 修正の起票元
- [Quality Gates](../operations/quality-gates.md) - PR 品質ゲートと action / Docker image のバージョン管理方針
- [Dependency Management](../operations/dependency-management.md) - npm 依存関係の更新方針と現行 contract
- [0017](./0017-pin-github-actions-by-owner-tier.md) - GitHub Actions を owner tier で固定する判断。決定時点の記録として Renovate / #350 への言及を残す
- [0025](./0025-pin-github-actions-docker-images-by-tag-and-digest.md) - workflow 内 Docker image を tag と digest で固定する判断。同上
- [0012](./0012-consolidate-iac-security-scan-on-trivy-config.md) - 同カテゴリのツールを増やさず 1 つに寄せる先例（tfsec を新規採用しない）
