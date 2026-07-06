# 0026. ALB系SLIをCloudWatch metric mathで算出しSLO burn-rateアラートに接続する

## ステータス

Accepted

## 日付

2026-07-06

## 決定内容

ALB系のSLI（応答時間・5xxエラー率）を、静的閾値アラームからCloudWatch metric mathベースのratio/比率SLIに再設計し、multi-window multi-burn-rate（fast burn / slow burn の2window）アラームとしてSNSに接続する（`terraform/modules/monitoring/main.tf`）。

- `nestjs-hannibal-3-alb-response-time-high` / `nestjs-hannibal-3-alb-5xx-error-rate-high` を廃止し、以下4つのアラームに置き換える
  - `nestjs-hannibal-3-slo-error-rate-fast-burn` / `-slow-burn`
  - `nestjs-hannibal-3-slo-response-time-fast-burn` / `-slow-burn`
- `canary-error-rate` / `canary-response-time`（CodeDeployのauto rollback接続用）と `ecs-task-stopped`（可用性計上の正本）は対象外とし、従来どおり静的閾値のまま維持する
- エラー率SLIは `IF(RequestCount(5分合計) >= 最小リクエスト数, (5xx count / RequestCount) * 100, 0)` というratio。低トラフィック時（最小リクエスト数未満）はratioを0%（non-breaching）として扱う
- 応答時間SLIは `TargetResponseTime(5分平均) / SLO目標値(1秒)` という比率（burn ratio）
- fast burnはevaluation_periods=1（5分window）、slow burnはevaluation_periods=6（30分window）とし、fast burnはより高い倍率、slow burnはより低い倍率をしきい値にする

## 背景

`docs/operations/slo.md` に文書化済みのSLO目標値（月次可用性99.5%、応答時間1秒未満、5xx rate 0.1%未満）は、これまで静的閾値のCloudWatchアラーム（`alb-response-time-high`: 1秒超過2期間、`alb-5xx-error-rate-high`: 5分合計5件超過）でしか計測・アラートされておらず、SLOの数値目標（%表記のエラー率、応答時間の秒数目標）と実際のアラーム閾値（絶対件数、絶対秒数）が直接対応していなかった。

Google SREの提唱するmulti-window multi-burn-rate alertingは、error budgetの消費速度（burn rate）を短時間窓（fast burn、急激な悪化を早期検知）と長時間窓（slow burn、緩やかな持続的悪化を検知）の2つで監視し、ノイズを抑えつつ実際にSLO違反につながる劣化を検知する手法である。本Issueではこれをこのプロジェクトの規模に合わせて簡略化して採用する。

### 低トラフィック時のratio暴れ

このプロジェクトはdev環境がコスト抑制のため通常destroy済みで運用され（ADR-0008）、常時起動していても実際のリクエスト数は少ない。5xx rateをratio（5xx count / total request count）として計算する場合、5分間のリクエスト数が極端に少ない（例: 2件）と、1件の5xxだけでratioが50%に跳ね上がり、実際には軽微な事象でもfast burnアラームが発報してしまう「ratio暴れ」が発生する。

### 応答時間SLIのratio化における限界

ALB（`AWS/ApplicationELB`）はリクエストごとの遅延ヒストグラムや「しきい値超過リクエスト数」のメトリクスを提供しない。`TargetResponseTime` はAverage/percentile（p50, p90, p99等のExtended Statistics）のみ提供される。したがって、真の意味での「SLO違反リクエストの割合」をmetric mathだけで算出することはできず、本ADRでは平均応答時間とSLO目標値の比（`resp_time / slo_target`）を近似的なburn ratioとして採用する。

## 検討した選択肢

### 低トラフィックガード: 最小リクエスト数未満はratioを0%扱い（採択）

- 長所: 実装がシンプル（metric mathの`IF()`のみで完結し、追加のcomposite alarmや補助リソースが不要）
- 長所: 低トラフィック時の偽陽性（false positive）burn-rateアラートを防げる
- 短所: 最小リクエスト数未満の時間帯に実際に5xxが集中していても、ratioとしては検知できない（マスクされる）。ただし、この場合も`HTTPCode_Target_5XX_Count`の絶対値は`runbook.md`のトラブルシュート手順で別途参照可能

### 最小リクエスト数未満はMISSING扱い + `treat_missing_data`で制御

- 長所: 「データなし」を明示的に表現でき、意味論的にはより正確
- 短所: CloudWatch metric mathの`IF()`はMISSINGを直接返せず、`FILL()`や複数alarmの組み合わせが必要になり実装が複雑化する
- 短所: このプロジェクトの規模・運用体制に対して過剰な複雑さになる

### 絶対数ベースの閾値を維持し、ratio化しない

- 長所: 実装変更が最小限で済む
- 短所: Issue #445の受け入れ条件（metric mathでSLIを算出しburn-rateアラートに接続する）を満たさない
- 短所: SLO目標（%表記）とアラーム閾値（絶対件数）の対応関係が今後も不明瞭なまま残る

### 応答時間SLIをExtended Statistics（p99等）ベースのSLO違反率にする

- 長所: 「p99が1秒を超えた比率」等、より精緻なSLI設計が可能
- 短所: ALBのExtended StatisticsはCloudWatch上でpercentile値の時系列は取得できるが、「percentileがしきい値を超えたリクエストの割合」を算出するには追加のログベース分析（Athenaでのアクセスログ解析等）が必要で、このIssueのスコープを超える
- 今後のTODOとして`docs/operations/slo.md`に記載し、必要になった時点で再検討する

### composite alarm（AND条件）でfast burnとslow burnの両方成立時のみ通知

- 長所: Google SREの原典によりノイズが少ない
- 短所: composite alarmは$0.50/月/個の追加コストが発生する（Issue補足に明記）。本プロジェクトはコスト抑制方針（ADR-0008）を取っており、fast/slow burnそれぞれ独立してSNS通知する設計（受け入れ条件の「2window」）で十分な検知性能を確保できると判断し不採用

## 採択理由

このプロジェクトはdev中心のポートフォリオ運用であり、低トラフィックによるratio暴れを完全に排除する精緻な設計よりも、実装のシンプルさと運用時の理解しやすさを優先する。`IF()`によるガードは、既存の`aws_lb_listener_rule`の`ignore_changes`パターン同様、Terraform/CloudWatchの標準機能のみで完結し、追加リソースやコストを発生させない。

応答時間SLIについても、真のパーセンタイルベースSLIではなく平均値ベースの近似で妥協するが、これは`slo.md`が元々「5分平均`TargetResponseTime`」を目標値として定義していたことと整合しており、既存のSLO定義を壊さずにburn-rate方式へ移行できる。

`canary-error-rate` / `canary-response-time` / `ecs-task-stopped` を対象外としたのは、それぞれCodeDeployの自動ロールバック接続、可用性計上の正本という別の役割を担っており、SLI/SLO再設計の対象にすると既存のデプロイ安全機構に影響するためである。

### `treat_missing_data`のECS系/ALB系不統一について

ECS系アラーム（`ecs-cpu-high`、`ecs-memory-high`、`ecs-task-stopped`）は`treat_missing_data = "breaching"`、ALB系アラーム（今回追加したSLO burn-rateアラームを含む）は`treat_missing_data = "notBreaching"`であり、設定が統一されていない。これは意図的な設計であり、単純な不統一ではないと整理する。

- ECS系: メトリクス欠損はタスクが動いていない（停止・起動失敗）ことを強く示唆するため、`breaching`（アラーム発火）にして異常を見逃さない
- ALB系: メトリクス欠損は多くの場合「その5分間にリクエストが来なかった」という正常な低トラフィックを意味するため、`notBreaching`にしてfalse alarmを避ける

この非対称性は今回のIssue #445のスコープでは変更せず、既存の設計判断として本ADRに明記するにとどめる。将来的にこの前提が崩れる場合（例: 常時高トラフィックを前提にする本番相当環境を追加する場合）は改めて見直す。

## 影響

- `terraform/modules/monitoring/main.tf`: `alb_response_time_high` / `alb_5xx_error_rate_high` を削除し、`slo_error_rate_fast_burn` / `slo_error_rate_slow_burn` / `slo_response_time_fast_burn` / `slo_response_time_slow_burn` を追加
- `terraform/modules/monitoring/variables.tf`: SLO burn-rateのしきい値・window・最小リクエスト数を variable化
- `docs/operations/slo.md`: 「SLI計測とburn-rateアラート」節を追加
- `docs/operations/runbook.md`: アラーム対応表と該当セクションを新しいアラーム名に更新
- `docs/operations/monitoring.md`: メトリクス節の記載を更新
- コスト影響: 新規SNS topic等は追加しないためcost:noneと判断。CloudWatch Alarmの追加数は2個増（旧2個→新4個）だが、Alarmの課金は基本料金内に収まる想定（`cost:small`未満）

## 関連

- [Issue #445](https://github.com/kmryst/terraform-hannibal/issues/445)
- [SLO](../operations/slo.md)
- [Runbook](../operations/runbook.md)
- [ADR 0008: オンデマンド起動 / 通常 destroy 運用を採用する](./0008-on-demand-startup-and-routine-destroy-operation.md)
- [ADR 0015: ECS デプロイに CodeDeploy Blue/Green を採用する](./0015-adopt-codedeploy-blue-green-for-ecs-deployments.md)
