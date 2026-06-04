# 0016. RDS PostgreSQL + JSONB を採用し、Aurora / PostGIS はスコープ外とする

## ステータス

Accepted

## 日付

2026-06-04

## 決定内容

`terraform-hannibal` のデータストアは、素の Amazon RDS for PostgreSQL（PostgreSQL 15）を採用し、ルート座標は PostGIS の geometry / geography 型ではなく PostgreSQL の JSONB 型で保持する。検索が必要な場合は JSONB に対する GIN index で対応する。

Amazon Aurora（PostgreSQL 互換）と PostGIS 拡張は、「将来再検討」ではなく、本プロジェクトの規模では**スコープ外として採用しない**ことを明示的な判断として記録する。両者を採用が正当化される閾値は本 ADR の「影響」に不採用の根拠として記載するが、demo / portfolio 用途の本プロジェクトでその閾値に到達する想定はない。

この ADR は、すでに実装済みの構成（RDS PostgreSQL + JSONB）を遡及的に記録し、採用しなかった選択肢の理由を残すものであり、Terraform の現行設定やアプリケーション実装を変更するものではない。

## 背景

このプロジェクトは、ハンニバルの進軍ルートを地図上に描画する 3 層 Web アプリケーションである。データモデルは Route Entity 1 つに集約され、座標は GeoJSON 互換の配列を JSONB 列（`coordinates JSONB`）に格納している。ルート数は限定的で、参照系のクエリは「全ルート取得」「ID 指定取得」が中心である。

dev 環境は本番サービスではなく、通常 destroy 済みで必要時だけ deploy するオンデマンド運用である（[0008](./0008-on-demand-startup-and-routine-destroy-operation.md)）。データベースに対して求めるのは、高スループットや大規模スケールではなく、TypeORM / NestJS から素直に扱え、起動・破棄が軽く、コストが小さいことである。

正本である `docs/architecture/data-architecture.md` でも、PostGIS 拡張は「未実装」であり、現在のデータ量では JSONB で十分とされている。一方で、なぜ Aurora ではなく素の RDS なのか、なぜ地理データを扱うのに PostGIS を入れないのか、という設計判断そのものは ADR として構造化されていなかった。

## 検討した選択肢

### RDS PostgreSQL + JSONB（採択）

- 長所: 単一の RDS インスタンスで完結し、起動・破棄が速くオンデマンド運用と相性がよい
- 長所: JSONB + GIN index で、現行のルート座標格納と参照には十分なパフォーマンスが出る
- 長所: TypeORM の `@Column('jsonb')` で素直にマッピングでき、アプリ側の実装が単純になる
- 長所: 最小構成のためコストが小さく、`db_instance_class` / `db_engine_version` を変数で制御できる
- 短所: 地理的範囲検索や距離計算が要件化した場合は、アプリ側または将来の拡張で対応する必要がある

### Amazon Aurora（PostgreSQL 互換）

- 長所: ストレージ自動拡張、高可用性、read replica による read スケールに優れる
- 長所: 大規模・高トラフィックの本番ワークロードでは運用面の利点が大きい
- 短所: クラスタ構成が前提で、最小構成でも素の RDS より構成要素とコストが増える
- 短所: オンデマンド起動 / 通常 destroy する dev では、起動・破棄の重さと費用が用途に見合わない
- 短所: ルート数が限定的な本プロジェクトでは、Aurora が解決するスケール課題が発生しない

### PostGIS 拡張の採用

- 長所: `geometry` / `geography` 型と空間 index（GIST）により、`ST_Within` / `ST_DWithin` / `ST_Distance` などの地理クエリを DB 側で実行できる
- 長所: 地理的範囲検索や距離計算が本格的に必要なアプリでは、JSONB より表現力・性能で優れる
- 短所: 拡張の有効化・スキーマ設計・移行が増え、現状の「描画するだけ」の機能に対して過剰になる
- 短所: 現在のクエリ（全件取得・ID 取得・GeoJSON 変換）は空間演算を必要とせず、JSONB + GIN で完結する
- 短所: データ量が少なく、PostGIS が解決する空間検索のボトルネックが発生しない

### 別データストア（DynamoDB 等）への移行

- 長所: サーバーレス課金で、アイドル時のコストをさらに抑えられる可能性がある
- 短所: TypeORM / リレーショナルモデル前提のアプリ実装を作り直す必要があり、移行コストが利点を上回る
- 短所: GraphQL リゾルバや既存の Route Entity 設計と整合させる利点が、現行規模では乏しい

## 採択理由

本プロジェクトのデータは Route Entity 1 つ、ルート数は限定的で、クエリは参照中心である。この規模では、データベースに求められるのはスケールや空間演算ではなく、TypeORM から素直に扱えること、起動・破棄が軽いこと、コストが小さいことである。素の RDS PostgreSQL + JSONB はこれらをすべて満たす。

Aurora は高可用性と read スケールに優れるが、それらが効くのは本プロジェクトには存在しないトラフィック・データ規模であり、オンデマンド起動 / 通常 destroy する dev では起動の重さとコストが用途に見合わない。

PostGIS は地理的範囲検索・距離計算・空間 index が要件化したときに価値を持つが、現行機能はルートを地図に描画するだけで、空間演算を一切必要としない。座標は JSONB に格納し、必要な検索は GIN index で足りる。地理データを扱うこと自体は PostGIS 採用の理由にならない。

したがって、Aurora と PostGIS は「いずれ入れるかもしれない将来候補」ではなく、本プロジェクトの規模では**採用しない**と判断する。これは機能不足ではなく、規模に対する right-sizing の判断であり、過剰な構成を避けることでコストと運用の単純さ（[0008](./0008-on-demand-startup-and-routine-destroy-operation.md)）を保つ。

## 影響

- データストアは単一の RDS PostgreSQL インスタンスを前提とし、`engine = "postgres"`、`engine_version` / `instance_class` を変数で制御する
- ルート座標は JSONB 列で保持し、検索が必要な場合は GIN index を用いる。アプリ側は TypeORM の `@Column('jsonb')` でマッピングする
- 地理クエリ（`ST_Within` / `ST_DWithin` / `ST_Distance` 等）や空間 index は使わない。地理的範囲検索・距離計算が機能要件として発生したときに、初めて PostGIS 採用を再検討する。ただし demo / portfolio 用途の本プロジェクトでその要件が発生する想定はない
- 高可用性・read replica・大規模 read スケールが必要になったときに、初めて Aurora 移行を再検討する。同様に、本プロジェクトでその規模に達する想定はない
- 上記の閾値は「将来の実装予定」ではなく、現時点で Aurora / PostGIS を採用しない根拠として記録する。閾値に達しない限り構成は変更しない
- この ADR 自体は docs-only であり、新しい AWS リソースやコストは発生しない

## 関連

- [Issue #303](https://github.com/kmryst/terraform-hannibal/issues/303)
- [docs/architecture/data-architecture.md](../architecture/data-architecture.md) - データモデル・JSONB 活用・PostGIS 未実装の正本
- [0008](./0008-on-demand-startup-and-routine-destroy-operation.md) - オンデマンド起動 / 通常 destroy 運用（コスト系判断の親前提）
- [0011](./0011-adopt-ecs-fargate-for-application-runtime.md) - アプリケーション実行基盤に ECS Fargate を採用する

RDS module（`engine` / `engine_version` / `instance_class` / JSONB 前提のスキーマ）の Terraform 実装は、正本である [data-architecture.md](../architecture/data-architecture.md) を起点に追う（module パスの直リンクは refactor で腐りやすいため ADR には固定しない）。
