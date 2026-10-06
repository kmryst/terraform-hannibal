# 0035. DB スキーマを TypeORM migrations で管理し、アプリ起動時に適用する

## ステータス

Accepted

## 日付

2026-10-06

## 決定内容

PostgreSQL のスキーマは TypeORM migrations だけで管理し、アプリケーションの起動時に未適用のマイグレーションを適用する。

- マイグレーションは `src/migrations/` に置き、`src/migrations/index.ts` でクラスを明示的に列挙する。初回マイグレーション `InitialSchema1791279966870` は、`Route` エンティティから `migration:generate` で生成した
- 接続設定は `src/database/typeorm-options.ts` の `createTypeOrmOptions()` に一本化し、アプリ（`TypeOrmModule.forRoot`）と TypeORM CLI（`src/database/data-source.ts`）が同じ設定を使う
- `migrationsRun: true`、`migrationsTransactionMode: 'all'` とし、未適用のマイグレーションを 1 つのトランザクションで適用する。適用済みかどうかは TypeORM の `migrations` テーブルで判定する
- `synchronize` は本番だけでなく全環境（development / test を含む）で無効にする
- `deploy.yml` の deploy 後に、CloudFront 経由で GraphQL の `routes`（読み取りのみ）を投げ、失敗したら workflow を失敗にする。同じ確認を PR Check の production 起動 smoke test（`Docker Build`）にも入れる（`scripts/deployment/verify-graphql-routes.sh`）

## 背景

destroy 済みの dev を `deploy.yml`（`deployment_mode=provisioning`）で作り直すと、RDS に `routes` テーブルがなく、GraphQL の `routes` / `route` / `createRoute` / `seedRoutes` が `relation "routes" does not exist` で失敗していた。

- `src/app.module.ts` が `synchronize: process.env.NODE_ENV !== 'production'`、`Dockerfile` と ECS タスク定義が `NODE_ENV=production` だった。本番イメージではスキーマを作る処理が何もなかった
- `terraform/database` は snapshot を使わず `skip_final_snapshot = true` のため、provisioning のたびに空の DB になる（[ADR 0008](./0008-on-demand-startup-and-routine-destroy-operation.md) の通常 destroy 運用）
- 2025-07-10 のコミット 99621db からこの状態だった。フロントと Synthetics canary（`capitalCities`）は DB を使わない固定データのクエリだけを使い、PR Check と deploy の起動確認は `/health` だけだったため、DB を通る経路を確かめる仕組みがなく、気づけなかった

経緯は Issue [#674](https://github.com/kmryst/terraform-hannibal/issues/674) を参照する。

## 検討した選択肢

### A. TypeORM migrations を導入し、アプリ起動時に `migrationsRun` で適用する（採択）

- 長所: スキーマの変更がコード（マイグレーションファイル）としてレビューされ、アプリのイメージと同じ単位でデプロイされる。deploy.yml・Terraform・IAM の変更が要らない。ローカル・CI・AWS が同じ経路でスキーマを作る。`migration:revert`（`down`）で戻せる
- 短所:
  - 起動のたびに `migrations` テーブルを読む（1 クエリ。起動時間への影響は実測で無視できる）
  - アプリの実行ユーザーに DDL を実行できる権限が要る。現状の RDS マスターユーザーをアプリが使う構成のままであり、権限は増えない
  - TypeORM の `migrationsRun` は、複数タスクが同時に起動したときのロック（PostgreSQL の advisory lock など）を取らない。後述「影響」のとおり、PostgreSQL の DDL がトランザクションで巻き戻ることと `@nestjs/typeorm` の接続リトライで自然に収束することを実測で確認した

### B. `deploy.yml` で一回限りの ECS タスク（`aws ecs run-task`）を起動してマイグレーションを流す

- 長所: マイグレーションの実行がアプリの起動から分離され、1 回だけ実行されることが保証される。失敗したときに deploy を止められる
- 短所: deploy.yml に、タスク定義・subnet・security group の取得、`run-task` の起動・終了待ち・終了コードの判定を追加する必要がある（CI/CD Role は `ecs:RunTask` と実行ロールの `iam:PassRole` を既に持つため、IAM の変更は要らない）。provisioning では image push の後、ECS service のタスクが起動する前に実行する順序制御が要る。ローカルや PR の smoke test では別の経路（CLI）でスキーマを作ることになり、AWS と同じ経路を確かめられない

### C. 本番でも `synchronize: true` にする

- 長所: 変更が 1 行で済む
- 短所: TypeORM のドキュメント（[How migrations work?](https://typeorm.io/docs/migrations/why/)）が、データの入った本番での `synchronize: true` は unsafe としている。エンティティの変更が、レビューされた DDL なしで起動時にそのまま反映される。列の型変更や名前変更では列を DROP → ADD してデータを失うことがある。変更履歴がなく、戻す手段がない

### D. 監視対象とは別の場所（外部 SaaS など）に外形監視を置く

- 長所: AWS の外から利用者と同じ経路を継続的に確認できる。AWS 側の障害で監視自体が止まることがない
- 今回採らない理由:
  - 今回の抜けは「どこから見るか」ではなく「何を確かめるか」の問題である。既存の Synthetics canary も外形監視だが、DB を通らない `capitalCities` しか見ていなかった。監視の場所を変えても、確かめる対象が同じなら同じ抜けが起きる
  - 環境を普段 destroy している（[ADR 0008](./0008-on-demand-startup-and-routine-destroy-operation.md)）ため、常時動く外部の監視は、環境を止めている間ずっと失敗を通知する。通知を止める運用が別に要る
  - 外部サービスのアカウント、API key などの secret、通知先の管理コストが増える
- 再検討条件: 環境を常時動かすようになったとき、利用者が付いたとき

## 採択理由

- 本番の `synchronize` を無効のまま、スキーマを作る仕組みをアプリ自身に持たせられ、Terraform や deploy.yml の順序制御に手を入れずに済む（B と比べて変更範囲が小さい）
- ローカル（Docker の PostgreSQL）、PR Check の smoke test、e2e テスト、AWS dev がすべて同じ「起動時に migrations を適用する」経路を通るため、PR の時点で AWS と同じ経路を確かめられる
- 全環境で `synchronize` を無効にすることで、開発環境では自動でテーブルができるのに本番ではできない、という今回の食い違いの原因そのものをなくす
- マイグレーションファイルとして DDL が残り、`down` で戻せる（C にはない）
- deploy 後の確認に GraphQL の `routes` を入れることで、DB を通る経路の確認という今回の抜けを直接埋める（D は確認する対象を変えない）

## 影響

- 開発者は、エンティティを変更したら `npm run migration:generate -- src/migrations/<Name>` でマイグレーションを生成し、`src/migrations/index.ts` に追記する。手順は [Data Architecture](../architecture/data-architecture.md) の「スキーマ管理（TypeORM migrations）」を正本とする
- 以前 `synchronize` でテーブルを作ったローカルの DB では、初回マイグレーションが `relation "routes" already exists` で失敗する。DB を作り直すか、`npm run migration:run -- --fake` で適用済みとして記録する。AWS dev の RDS は provisioning のたびに空なので該当しない
- 本番イメージは `dist/database/data-source.js` を使って TypeORM CLI（`node node_modules/typeorm/cli.js`）を実行できる。AWS 上でマイグレーションを戻す手順は [Runbook](../operations/runbook.md) の「スキーマ変更を含むデプロイの rollback」を正本とする
- CodeDeploy の Canary / Blue/Green では、新旧のタスクが同じ DB を同時に使う。マイグレーションは 1 つ前のバージョンのアプリでも動く後方互換な変更（expand and contract パターン）にする
- 複数タスクの同時起動: TypeORM はマイグレーションの実行にロックを取らない。2 つのコンテナを同時に起動して `migrations` テーブルの読み取りを揃えた検証では、一方が `CREATE TABLE` に成功し、もう一方は `duplicate key value violates unique constraint "pg_class_relname_nsp_index"` で失敗した。失敗した側はトランザクション全体（`migrations` テーブルへの記録を含む）が巻き戻り、`@nestjs/typeorm` の接続リトライ（既定で 3 秒間隔、最大 10 回の試行）で再初期化したときに `No migrations are pending` となって起動した。`migrations` テーブルの記録は 1 件だけだった。現在の `desired_task_count` は 1 で、この状況は通常起きない
- 本番のログは `['error', 'schema', 'migration']` を出力する。マイグレーションの適用状況（`Migration InitialSchema1791279966870 has been executed successfully.` / `No migrations are pending`）が CloudWatch Logs（`/ecs/nestjs-hannibal-3-api-task`）に出る。`error` により失敗したクエリと parameter もログに出る（現状の parameter は route の名前・説明・座標・色で、secret は含まない）
- `deploy.yml` は deploy 後の GraphQL `routes` の確認に最大 20 分待つ。provisioning では ECS タスクが image push の後に起動するため、成功するまで再試行する

## 再検討条件

- `desired_task_count` を 2 以上にする、または auto scaling を入れるとき（advisory lock でマイグレーションを直列化するか、B の一回限りのタスクへの移行を検討する）
- 長時間かかるマイグレーション（大きなテーブルへのインデックス作成など）が必要になったとき。ECS のヘルスチェック猶予（`health_check_grace_period_seconds = 180`）を超えるとタスクが入れ替えられるため、B を検討する
- アプリの DB ユーザーを DDL 権限のない専用ユーザーに分けるとき（マイグレーション用の資格情報と実行経路を分ける必要があり、B が前提になる）
- 環境を常時動かすようになったとき、利用者が付いたとき（D の外部の外形監視を再検討する）

## 関連

- Issue: [#674](https://github.com/kmryst/terraform-hannibal/issues/674)
- [ADR 0008](./0008-on-demand-startup-and-routine-destroy-operation.md)（オンデマンド起動 / 通常 destroy 運用）
- [ADR 0015](./0015-adopt-codedeploy-blue-green-for-ecs-deployments.md)（CodeDeploy Blue/Green）
- [ADR 0016](./0016-adopt-rds-postgresql-jsonb-over-aurora-and-postgis.md)（RDS PostgreSQL + JSONB）
- [ADR 0030](./0030-adopt-cloudwatch-synthetics-canary-for-user-journey-monitoring.md)（CloudWatch Synthetics canary）
- [Data Architecture](../architecture/data-architecture.md)（スキーマと migrations の手順の正本）
- [Runbook](../operations/runbook.md)（AWS 上での rollback 手順の正本）
- [TypeORM: How migrations work?](https://typeorm.io/docs/migrations/why/)
