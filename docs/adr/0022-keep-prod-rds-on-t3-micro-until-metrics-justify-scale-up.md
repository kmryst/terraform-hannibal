# 0022. prod RDS はメトリクスが引き上げを正当化するまで db.t3.micro に据え置く

## ステータス

Accepted

## 日付

2026-06-24

## 決定内容

prod 相当の RDS PostgreSQL は、初期構成では dev と同じ `db.t3.micro` に据え置く。
`db.t3.small`、`db.t4g.small`、`db.r5.large` などへの引き上げは、事前の推奨値として固定せず、実際の負荷と CloudWatch メトリクスで必要性が確認できた時点で判断する。

引き上げ判断では、少なくとも次のメトリクスを見る。

- `CPUUtilization`: 通常負荷で 60% を継続的に超える、またはスパイクではなく繰り返し高止まりする
- `DatabaseConnections`: 既存閾値の 12 接続付近で継続し、アプリ側の connection pool 枯渇や待ちが観測される
- `FreeableMemory`: 通常負荷で 200 MiB を下回る状態が継続する、またはメモリ不足に起因する swap / 再起動 / 性能劣化が疑われる
- `CPUCreditBalance`: 通常負荷で 20 credits 未満まで低下する状態が継続する、または 0 への枯渇が繰り返される

`FreeableMemory` と `CPUCreditBalance` は、この ADR 記録時点では Terraform の monitoring module に alarm / dashboard として未実装である。
したがって、これらを引き上げ判断の正式な観測材料にする前に、後続 Issue #349 で監視手段を追加する。

## 背景

repo 内の過去ドキュメントでは、prod の RDS instance class が `db.t3.small`、`db.t4g.small`、`db.r5.large` と複数の候補に分裂していた。
一方で、それらを採用する設計根拠や、どの負荷で引き上げるかの判断条件は記録されていなかった。

このプロジェクトは demo / portfolio 用途を主眼にした 3 層 Web アプリケーションであり、RDS は PostgreSQL + JSONB を採用している（ADR 0016）。
dev は通常 destroy 済みで必要時だけ起動するオンデマンド運用であり、コストと再現性のバランスを重視する（ADR 0008）。
prod 相当を追加する場合も、最初から過剰な instance class を選ぶより、測定可能な負荷を見て段階的に引き上げる方が、このプロジェクトの right-sizing 方針に合う。

現在の Terraform 実装でも、`terraform/modules/rds` と `terraform/database` の `db_instance_class` 既定値は `db.t3.micro` である。
既存の monitoring module は RDS の `CPUUtilization` と `DatabaseConnections` を alarm / dashboard に含めているが、`FreeableMemory` と `CPUCreditBalance` は未監視である。

## 検討した選択肢

### `db.t3.micro` に据え置く（採択）

- 長所: 既存 Terraform の既定値と一致し、dev / prod 相当の初期差分を最小化できる
- 長所: 低コストで開始し、実負荷に基づいて段階的に引き上げられる
- 長所: burstable instance の credit と CPU / connection / memory の実測を見て判断できる
- 短所: prod 相当の常時稼働や利用者増が発生した場合、早めに監視と引き上げ判断が必要になる

### `db.t3.small` に事前引き上げする

- 長所: `db.t3.micro` よりメモリと余裕が増え、軽い常時稼働では安心感がある
- 短所: 現時点では負荷根拠がなく、初期コストだけが増える
- 短所: 引き上げ基準が曖昧なまま推奨値だけが残り、後続の docs / Terraform 変更が根拠を追いにくくなる

### `db.t4g.small` に切り替える

- 長所: ARM 系 Graviton の price / performance が良い可能性がある
- 短所: instance family の切り替えを正当化する負荷やコスト比較がまだない
- 短所: 現在の課題は price / performance 最適化ではなく、prod 相当で引き上げが必要かどうかの判断基準不足である

### `db.r5.large` に引き上げる

- 長所: メモリ余裕が大きく、DB 負荷の高い本番ワークロードでは選択肢になり得る
- 短所: demo / portfolio 用途の初期 prod 相当には明らかに過剰
- 短所: コスト影響が大きく、ADR 0008 のコスト抑制方針と相性が悪い

## 採択理由

prod 相当を追加する時点で重要なのは、固定的な「本番推奨サイズ」を先に決めることではなく、どの指標が悪化したら引き上げるかを先に決めることである。

`db.t3.micro` は既存 Terraform の既定値であり、現行アプリケーション規模では最小構成から始める判断が妥当である。
`db.t3.small` / `db.t4g.small` / `db.r5.large` はいずれも将来の候補にはなるが、現時点では負荷・メモリ・CPU credit の実測が不足している。
根拠なしに引き上げると、ドキュメント上の「推奨」が一人歩きし、コストと運用の単純さを優先する既存 ADR と衝突しやすい。

したがって、prod 相当の初期 RDS は `db.t3.micro` に据え置き、`CPUUtilization` / `DatabaseConnections` / `FreeableMemory` / `CPUCreditBalance` を観測してから引き上げる。
ただし `FreeableMemory` と `CPUCreditBalance` は現時点で未監視のため、#349 で alarm / dashboard を追加してから判断材料として使う。

## 影響

- `docs/terraform-environments.md` の prod RDS 推奨は、`db.t3.small` 以上ではなく `db.t3.micro` 据え置きとメトリクス判断に更新する
- Terraform の `db_instance_class` 既定値は変更しない
- この ADR は docs-only であり、新しい AWS リソースやコストは発生しない
- prod 相当環境を追加する PR では、RDS instance class を上げる前に、この ADR のメトリクス条件と監視状況を確認する
- `FreeableMemory` / `CPUCreditBalance` の監視は #349 の Terraform 変更で扱うため、この ADR では実装しない

## 関連

- [Issue #348](https://github.com/kmryst/terraform-hannibal/issues/348)
- [Issue #349](https://github.com/kmryst/terraform-hannibal/issues/349)
- [ADR 0008: オンデマンド起動 / 通常 destroy 運用を採用する](./0008-on-demand-startup-and-routine-destroy-operation.md)
- [ADR 0016: RDS PostgreSQL + JSONB を採用し、Aurora / PostGIS はスコープ外とする](./0016-adopt-rds-postgresql-jsonb-over-aurora-and-postgis.md)
- [Terraform 環境分離設計](../terraform-environments.md)
