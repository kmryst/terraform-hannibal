# Game Day演習記録: ECSタスク強制停止（Issue #458 blast radius分離後の初回検証）

`docs/operations/game-day-exercise-template.md`の形式に基づく記録。元記録はIssue #447コメント（[#4895599298](https://github.com/kmryst/terraform-hannibal/issues/447#issuecomment-4895599298)）。

## 実施概要

- **実施日時（UTC）**: 2026-07-06T17:07:59Z 〜 17:08:39Z（実験自体は約40秒で`completed`）
- **実施者**: Claude Code（Issue #458マージ後の検証作業として）
- **対象環境**: dev（`nestjs-hannibal-3-cluster` / `nestjs-hannibal-3-api-service`）
- **FIS experiment ID**: `EXPnQRxcL2CF3yGRaJ`
- **FIS experiment template ID**: `EXT3JFNzCUax5cmn`（`terraform/observability`から独立取得。Issue #458のblast radius分離後、初のGame Day実行）
- **deployment_mode**: 直前に`canary`でdeploy済み（run 28808478372、成功）

## 実施手順

1. [x] `terraform/service`と`terraform/observability`がapply済みで、ECSサービスが`ACTIVE`であることを確認した
2. [x] `./scripts/game-day/run-ecs-task-stop-experiment.sh`を実行した
3. [x] 実験が終端状態（`completed`）になるまで待った
4. [x] ECSサービスの`runningCount`が`desiredCount`まで自動復旧したことを確認した
5. [x] CloudWatch Alarmの発火有無を確認した
6. [x] 本テンプレートに結果を記録した
7. [x] destroyは本演習では自動実行していない（destroy.ymlは別途、検証完了後に人間の判断でトリガー）

## 結果記録

| 項目 | 結果 |
| --- | --- |
| 実験開始時刻（UTC） | 2026-07-06T17:07:59Z |
| 実験終了時刻（UTC） | 2026-07-06T17:08:39Z |
| 実験の終端ステータス | `completed`（stop conditionによる自動停止ではなく正常完了） |
| stop conditionで自動停止したか | No |
| ECSタスクの復旧に要した時間（停止検知〜runningCount回復） | 約70〜90秒（FIS実験終了直後の`STABILIZING`遷移から新タスクの`RUNNING`確認まで） |
| `nestjs-hannibal-3-ecs-task-stopped`アラーム発火 | Yes |
| `nestjs-hannibal-3-slo-error-rate-fast-burn`アラーム発火 | No（`OK`） |
| `nestjs-hannibal-3-slo-error-rate-slow-burn`アラーム発火 | No（`OK`） |
| `nestjs-hannibal-3-slo-response-time-fast-burn`アラーム発火 | No（`OK`） |
| `nestjs-hannibal-3-slo-response-time-slow-burn`アラーム発火 | No（`OK`） |
| CodeDeployのデプロイ状態への影響 | 影響なし（演習実施時にcanary/bluegreenデプロイは進行していなかった） |
| 利用者影響 | 単一タスク構成のため、停止中に瞬断が発生した可能性があるが、SLO burn-rateアラームは発火せず許容範囲内 |
| 想定外の挙動 | ECS `describe-services`の`runningCount`反映に数秒のラグがあったのみ。致命的な想定外挙動はなし |

停止されたタスクは`95224839ae96407cb32af686d0c7acee`で、`stoppedReason`が`"Task stopped by AWS FIS (Experiment ID: EXPnQRxcL2CF3yGRaJ)"`と明確に記録されており、FISによる意図的な停止であることを確認できた。

## 振り返り

- **うまく機能した点**:
  - Issue #458のblast radius分離が実運用でも機能し、`terraform/observability`が本体（`terraform/service`）から独立してFIS実験テンプレートIDを提供できた
  - FIS実験テンプレートが`COUNT(1)`で正しく1タスクのみを選び停止した
  - ECSスケジューラによる自動復旧（CodeDeployを介さない直接再作成）が正常に機能した
  - `nestjs-hannibal-3-ecs-task-stopped`アラームが正しく発火し、意図した検知ができた
  - SLO burn-rateアラーム（Issue #445）は単発の意図的停止では発火せず、過剰検知にならないことを確認できた
  - 演習スクリプトは`destroy.yml`を一切トリガーしなかった（安全設計どおり）
- **改善が必要な点**:
  - ECS `describe-services`の`runningCount`はタスクの実際の`RUNNING`状態への遷移後、数秒のラグをもって反映される場合がある。監視・自動化スクリプトでは即時反映を前提にしない設計が必要
  - 今回はGame Day演習の結果を当初Issueコメントのみに記録しており、正式なドキュメントとして`docs/`にコミットするのを忘れていた（本ファイルはその是正、Issue #461）
- **runbook.md / SLO / IAMへのフィードバック**:
  - 特になし。今回の演習範囲では既存の設計（ADR-0026, 0027, 0028, 0029）どおりに機能した
