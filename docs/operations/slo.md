# SLO

この文書は、`nestjs-hannibal-3` を起動している間の最小限の SLO
（Service Level Objective）を定義する。

このプロジェクトの dev 環境はコスト抑制のため、通常 destroy 済みで運用する。
そのため、ここでの SLO は「サービスを利用可能な状態として deploy / provisioning している期間」を対象にする。
計画的な destroy、Terraform apply 中の切替時間、明示的なメンテナンス時間は SLO 対象外とする。

## 対象サービス

| 項目       | 対象                                                            |
| ---------- | --------------------------------------------------------------- |
| Public API | `https://api.hamilcar-hannibal.click` 配下の ALB 経由リクエスト |
| Frontend   | CloudFront + S3 で配信する React client                         |
| Backend    | ECS Fargate 上の NestJS API                                     |
| Database   | RDS PostgreSQL                                                  |

まずは ALB / ECS / RDS の CloudWatch メトリクスで利用者影響を判断する。
アプリケーション固有の詳細メトリクスは、必要になった時点で追加する。

## Service Level Indicators

| SLI              | CloudWatch で見るもの                                                    | 判定の考え方                                                                         |
| ---------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| レスポンスタイム | `AWS/ApplicationELB` の `TargetResponseTime`                             | ALB から ECS target までの平均応答時間を見る                                         |
| エラー率         | `AWS/ApplicationELB` の `HTTPCode_Target_5XX_Count` と HTTP status count | 5xx をサーバ側エラーとして扱う。4xx は原則として利用者入力や認証由来として分ける     |
| 稼働率           | ECS `RunningTaskCount`、ALB target health、CodeDeploy status             | 起動期間中に少なくとも期待する ECS task が healthy target として応答しているかを見る |
| デプロイ健全性   | CodeDeploy deployment status、canary 用 CloudWatch Alarm                 | canary / bluegreen の切替中に 5xx と応答時間が悪化していないかを見る                 |

## SLO

| 項目             | 目標                                                                                                         | 既存アラートとの関係                                                                                                 |
| ---------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| レスポンスタイム | 起動期間中の 5分平均 `TargetResponseTime` を 1秒未満に保つ。通常時の運用目安は 200ms 未満                    | `nestjs-hannibal-3-slo-response-time-fast-burn` / `nestjs-hannibal-3-slo-response-time-slow-burn` がburn rateを検知する（詳細は「SLI計測とburn-rateアラート」節） |
| エラー率         | 起動期間中の target 5xx rate を 0.1% 未満に保つ。低トラフィック時は 5分あたり 5件以上の 5xx を調査対象にする | `nestjs-hannibal-3-slo-error-rate-fast-burn` / `nestjs-hannibal-3-slo-error-rate-slow-burn` がburn rateを検知する（詳細は「SLI計測とburn-rateアラート」節） |
| 稼働率           | 起動期間中の月次可用性 99.5% 以上を目標にする                                                                | `nestjs-hannibal-3-ecs-task-stopped` または `nestjs-hannibal-3-slo-error-rate-slow-burn` が ALARM 状態だった時間の合計に加え、CloudWatch Synthetics canary の time-based availability（正常時間窓の比率、詳細は「SLI計測とburn-rateアラート」節）を月次停止時間の判断材料として扱う（ADR-0030） |
| デプロイCanary 安全性 | デプロイ時の canary 段階では 1分単位で 5xx と応答時間を監視し、悪化時は CodeDeploy の auto rollback を優先する | `nestjs-hannibal-3-canary-error-rate` と `nestjs-hannibal-3-canary-response-time` を CodeDeploy alarm として利用する。canary 用応答時間アラームの閾値は 2秒（定常 SLO の 1秒より緩め）。デプロイ時のコンテナ起動・接続プール初期化による一時的な遅延と実際の品質劣化を切り分けるため意図的に乖離させている。※CloudWatch Synthetics canary（外形監視）とは別物 |

## SLI計測とburn-rateアラート

ALB系（応答時間 / 5xx）のSLIは、CloudWatch metric mathで算出したうえでmulti-window multi-burn-rateアラーム（fast burn / slow burn）としてSNSに接続する（`terraform/modules/monitoring/main.tf`）。`canary-error-rate` / `canary-response-time`（CodeDeployのauto rollback用）と `ecs-task-stopped`（可用性計上の正本）は本方式の対象外として、従来の静的閾値アラームのまま維持する。

### エラー率SLI

- `error_ratio = IF(RequestCount(5分合計) >= 最小リクエスト数, (5xx count / RequestCount) * 100, 0)`
- 最小リクエスト数未満の5分間はratioを0%（non-breaching）として扱う。低トラフィック時のratio暴れ対策の設計判断は [ADR-0026](../adr/0026-slo-burn-rate-alerts-for-alb-slis.md) を参照
- fast burn: 5分window、error budget（0.1%）の14.4倍（1.44%）超過で発報
- slow burn: 30分window（5分x6期間）、error budget（0.1%）の3倍（0.3%）超過で発報

### 応答時間SLI

- `resp_ratio = TargetResponseTime(5分平均) / SLO目標値(1秒)`
- ALBはリクエストごとの遅延ヒストグラムを提供しないため、平均応答時間としきい値の比をburn rateの近似として扱う。この近似の限界と代替案は [ADR-0026](../adr/0026-slo-burn-rate-alerts-for-alb-slis.md) を参照
- fast burn: 5分window、比が2.0（平均応答時間がSLO目標の2倍）超過で発報
- slow burn: 30分window、比が1.2（平均応答時間がSLO目標の1.2倍）超過で発報

### 稼働率SLI（CloudWatch Synthetics canary、time-based availability）

ALB系SLI（エラー率・応答時間）はratio（比率）ベースで算出するのに対し、稼働率SLIはratioベースではなくtime-based availability（固定間隔ヘルスチェックにおける正常時間窓の比率）を採用する。canaryは固定間隔（例: 5分ごと）で実行され、実行のたびに成功/失敗の二値結果しか得られないため、実行回数ベースのratioとして扱うと、ADR-0026で扱った「低トラフィック時のratio暴れ」と同種の問題（少数の失敗が比率を急変させる）が発生しうる。この設計判断の詳細は [ADR-0030](../adr/0030-adopt-cloudwatch-synthetics-canary-for-user-journey-monitoring.md) を参照。

- CloudWatch Synthetics の `SuccessPercent` メトリクスを、一定期間（例: 1時間）で平均した値を、その期間中のcanary可用性の近似として扱う
- 検証対象はフロントエンド配信（CloudFront経由）、GraphQL読み取りクエリ（`capitalCities` / `hannibalRoute` / `pointRoute` 等）、ヘルスチェック（`GET /`）の3点に限定する。書き込み系API（GraphQL Mutation）と認証済みユーザー操作（本アプリには認証機能自体が存在しない）は対象外
- canaryのTerraformリソースはenv側（アプリ実行系と同じroot module群）に配置し、`deploy.yml` / `destroy.yml` によるオンデマンド起動・破棄と生死を共にする（[ADR-0008](../adr/0008-on-demand-startup-and-routine-destroy-operation.md) との整合）
- canaryの成功/失敗結果は、既存の`terraform/modules/monitoring`のSNS topicへの接続を後続Issueで行う

## 計測方法

CloudWatch Dashboard は Terraform の `module.monitoring` で作成する。
まず次を確認する。

- Dashboard: `hannibal-system-dashboard`
- ECS: `CPUUtilization`, `MemoryUtilization`, `RunningTaskCount`
- RDS: `CPUUtilization`, `DatabaseConnections`
- ALB: `TargetResponseTime`, `HTTPCode_Target_2XX_Count`, `HTTPCode_Target_4XX_Count`, `HTTPCode_Target_5XX_Count`
- Logs: `/ecs/nestjs-hannibal-3-api-task`

CLI で確認する場合の例:

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix nestjs-hannibal-3 \
  --region ap-northeast-1

aws ecs describe-services \
  --cluster nestjs-hannibal-3-cluster \
  --services nestjs-hannibal-3-api-service \
  --region ap-northeast-1

aws logs tail /ecs/nestjs-hannibal-3-api-task \
  --since 30m \
  --region ap-northeast-1
```

## エラーバジェット

dev 中心のポートフォリオ運用では、厳密な SLA ではなく改善判断の材料として扱う。
月次で次のどれかに当てはまる場合は、運用改善 Issue を作る。

- 起動期間中の可用性が 99.5% を下回った
- `TargetResponseTime` 1秒超過が複数回発生した
- 5xx が同じ原因で繰り返し発生した
- canary / bluegreen deployment の rollback が発生した

改善 Issue では、原因、利用者影響、暫定対応、恒久対応を記録する。
