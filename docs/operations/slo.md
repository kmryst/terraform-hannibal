# SLO - NestJS Hannibal 3

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
| レスポンスタイム | 起動期間中の 5分平均 `TargetResponseTime` を 1秒未満に保つ。通常時の運用目安は 200ms 未満                    | `nestjs-hannibal-3-alb-response-time-high` が 1秒超過を 2期間連続で検知する                                          |
| エラー率         | 起動期間中の target 5xx rate を 0.1% 未満に保つ。低トラフィック時は 5分あたり 5件以上の 5xx を調査対象にする | `nestjs-hannibal-3-alb-5xx-error-rate-high` が 5分合計 5件超過を検知する                                             |
| 稼働率           | 起動期間中の月次可用性 99.5% 以上を目標にする                                                                | `nestjs-hannibal-3-ecs-task-stopped` または `nestjs-hannibal-3-alb-5xx-error-rate-high` が ALARM 状態だった時間の合計を月次停止時間として扱う。本環境は destroy/deploy 運用のため外形監視（CloudWatch Synthetics 等）は導入していない。本番相当環境では Synthetics Canary による black-box 監視を追加する |
| Canary 安全性    | canary 中は 1分単位で 5xx と応答時間を監視し、悪化時は CodeDeploy の auto rollback を優先する                | `nestjs-hannibal-3-canary-error-rate` と `nestjs-hannibal-3-canary-response-time` を CodeDeploy alarm として利用する。canary 用応答時間アラームの閾値は 2秒（定常 SLO の 1秒より緩め）。デプロイ時のコンテナ起動・接続プール初期化による一時的な遅延と実際の品質劣化を切り分けるため意図的に乖離させている |

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
