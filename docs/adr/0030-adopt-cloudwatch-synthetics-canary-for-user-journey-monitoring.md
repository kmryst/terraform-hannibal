# 0030. ユーザージャーニーレベルの外形監視にCloudWatch Synthetics canaryを採用する

## ステータス

Accepted

## 日付

2026-07-07

## 決定内容

`nestjs-hannibal-3` の dev 環境（on-demand / ephemeral、[ADR-0008](./0008-on-demand-startup-and-routine-destroy-operation.md)）に対し、CloudWatch Synthetics canary によるユーザージャーニーレベルの外形監視（black-box monitoring）を導入する。

- 検証対象は次の3点に限定する
  - フロントエンド配信（CloudFront 経由の React client 配信確認）
  - GraphQL 読み取りクエリ（`capitalCities` / `hannibalRoute` / `pointRoute` などの `Query`。`src/modules/map`, `src/modules/route` 参照）
  - ヘルスチェック（`GET /`、`src/app.controller.ts`）
- 書き込み系 API（GraphQL `Mutation`）は検証対象外とする。テストデータの作成・後始末の管理が複雑化するため
- 認証済みユーザー操作の検証は対象外とする。本アプリには認証機能自体が存在しない（コントローラ・リゾルバに auth / jwt / passport 相当の実装がない）ため、そもそも検証しようがない
- canary の Terraform リソースは foundation 側ではなく env 側（アプリ実行系と同じ root module 群）に配置し、`deploy.yml` / `destroy.yml` によるオンデマンド起動・破棄と生死を共にする
- 稼働率 SLI は、5xx ratio のような比率ベースではなく time-based availability（固定間隔ヘルスチェックにおける正常時間窓の比率）を採用する

## 背景

`docs/operations/slo.md` の稼働率 SLO は、ECS `RunningTaskCount` と ALB target health、`ecs-task-stopped` アラームでのみ計測しており、実際にインターネット経由でエンドユーザーが到達できるか（CloudFront・DNS・TLS・ALB・ECS を貫通する経路全体）を検証する外形監視を持っていなかった。ALB/ECS のサーバサイドメトリクスは、ロードバランサーより手前（CloudFront のキャッシュ動作・オリジン到達性、DNS 解決、証明書の有効性など）の障害を検知できない盲点がある。

このプロジェクトは本番サービスではなくポートフォリオ用の dev 中心運用であり、実際のユーザートラフィックは少ない。したがって監視精度だけを最大化する動機は薄い。

### Synthetics 導入理由の trade-off（正直な整理）

このアプリの監視精度だけを考えるなら、EventBridge Scheduler + Lambda で `curl` 相当のチェックを行う自前の smoke test スクリプトの方が、実装もコストも軽い。CloudWatch Synthetics は Puppeteer/Selenium ベースのランタイムを内部で起動するため、単純な HTTP ヘルスチェックに対しては明らかにオーバースペックである。

それでも本 ADR では Synthetics を選ぶ。理由は、マネージド外形監視サービスの構築・運用経験（canary スクリプトの作成、IAM 実行ロールの最小権限設計、S3 artifact 管理、CloudWatch Alarm との接続）を DevOps / SRE / Platform Engineering のポートフォリオとして示すためである。技術的な最適解ではなく、学習・提示価値を優先した意思決定であることをここに明記する。

## 検討した選択肢

### 自前 smoke test（EventBridge Scheduler + Lambda + curl 相当）

- 長所: 実装がシンプル。Lambda 呼び出し課金のみで Synthetics canary 実行料より安い。依存が少なく障害点も少ない
- 短所: マネージド外形監視サービスの構築・運用経験としてのポートフォリオ価値が低い。スクリーンショットや HAR ファイルなどの failure artifact 収集、ブラウザベースの実ユーザー体験に近い検証は自前実装だと追加開発が必要
- 不採用理由: 本 Issue の主目的はポートフォリオとしての Synthetics 運用経験の獲得であるため

### CloudWatch Synthetics canary（採択）

- 長所: AWS マネージドサービスとしての構築・運用経験を示せる。`heartbeat` / `api` blueprint が既製で用意されており、失敗時のスクリーンショット・HAR ファイルが自動で S3 に保存される。既存の CloudWatch ベースの監視基盤（ADR-0026 の metric math / burn-rate アラーム）と同じ CloudWatch namespace 上で完結し、ツールの一貫性を保てる
- 短所: 単純なヘルスチェックに対してはランタイムがオーバースペックで、canary 実行自体にコストが発生する（起動中のみ課金だが `cost:none` ではなく `cost:small` 相当）
- 採択理由: 上記 trade-off の通り、監視精度の最適化よりポートフォリオとしての提示価値を優先する

### サードパーティ外形監視サービス（Pingdom 等）

- 長所: 設定が容易でAWS外からの疎通確認ができる
- 短所: AWS外部のサービスとの契約・APIキー管理が必要になり、このプロジェクトが一貫して採用している「AWSネイティブなIaCで完結させる」方針（Terraformでの一元管理）から外れる。ポートフォリオとして示したいのもAWSの運用経験であるため、本 Issue のスコープ外とする

## 稼働率 SLI: time-based availability を採用する理由

エラー率・応答時間 SLI は [ADR-0026](./0026-slo-burn-rate-alerts-for-alb-slis.md) で比率（ratio）ベースの metric math に再設計したが、その際に「低トラフィック時に ratio が暴れる」という教訓を得ている（5分間のリクエスト数が極端に少ないと、1件の失敗だけで ratio が跳ね上がる）。

canary は固定間隔（例: 5分ごと）で実行され、実行のたびに成功/失敗の二値結果が得られる。これを ratio（成功数 / 全実行数）として扱うと、canary 自体の実行頻度が低いため、ADR-0026 と同種の暴れが発生しうる。そのため、稼働率 SLI は ratio ベースではなく、time-based availability（canary が正常だった時間窓の合計 / 起動期間全体の時間）として定義する。CloudWatch Synthetics の `SuccessPercent` メトリクスは実行回数ベースの成功率を返すため、これを「直近の失敗から次の成功までの経過時間」に変換するのではなく、`SuccessPercent` を一定期間（例: 1時間）で平均した値を、その期間中の canary 可用性の近似として扱う。これにより、少数の実行回数による ratio 暴れを緩和しつつ、実装を simple math の範囲に収める。

## 採択理由

このプロジェクトは dev 中心のポートフォリオ運用であり、監視の技術的完成度そのものよりも、マネージド外形監視サービスを IaC で構築・運用し、既存の CloudWatch ベースの監視基盤（ADR-0026）に統合する経験を示すことに価値がある。この意思決定はコスト最適や実装の単純さを犠牲にしているが、その trade-off を隠さず記録することが、正直な設計判断の提示としてポートフォリオの価値を高めると判断する。

canary を env 側に配置し on-demand deploy/destroy と生死を共にする設計は、ADR-0008 の運用前提（通常は destroy 済み、必要時のみ起動）と整合する。foundation 側（永続リソース）に置くと、アプリ本体が destroy 済みの間も canary だけが空振りし続け、無意味な失敗アラームが発報し続けるため不適切である。

## 影響

- `docs/operations/slo.md`: 「稼働率」SLI の記述を time-based availability ベースに更新し、Synthetics 導入後の測定方法を追記する
- 後続 Issue で `terraform/service`（または同等の env 側 root module）に canary 用リソース（IAM role、S3 artifact バケット、canary script、schedule）を追加する
- 後続 Issue で canary の成功/失敗結果を CloudWatch Alarm 経由で `terraform/modules/monitoring` の SNS topic に接続する
- コスト影響: canary 実行中のみ課金が発生する（Synthetics canary 実行料、S3 artifact 保存料）。env 起動期間中は `cost:small` 相当と見込む。本 ADR 自体（ドキュメントのみ）は `cost:none`

## 関連

- [docs/operations/slo.md](../operations/slo.md)
- [ADR 0008: オンデマンド起動 / 通常 destroy 運用を採用する](./0008-on-demand-startup-and-routine-destroy-operation.md)
- [ADR 0026: ALB系SLIをCloudWatch metric mathで算出しSLO burn-rateアラートに接続する](./0026-slo-burn-rate-alerts-for-alb-slis.md)
- [Issue #463](https://github.com/kmryst/terraform-hannibal/issues/463)
