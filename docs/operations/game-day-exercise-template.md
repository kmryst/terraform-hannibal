# Game Day演習 記録テンプレート

AWS FISでECSタスクを意図的に停止させるGame Day演習(Issue #447)の実施記録テンプレート。
演習1回につき本テンプレートをコピーし、`docs/operations/game-day-exercises/<日付>-<概要>.md`等に記録するか、
関連PR/Issueのコメントに貼り付けて記録する。

## 実施概要

- **実施日時（UTC）**:
- **実施者**:
- **対象環境**: dev（`nestjs-hannibal-3-cluster` / `nestjs-hannibal-3-api-service`）
- **FIS experiment ID**:
- **FIS experiment template ID**:
- **deployment_mode**（canary / bluegreen / provisioning直後 等）:

## 実施手順

1. [ ] `terraform/service`と`terraform/observability`がapply済みで、ECSサービスが`ACTIVE`であることを確認した
2. [ ] `./scripts/game-day/run-ecs-task-stop-experiment.sh`を実行した
3. [ ] 実験が終端状態（`completed`/`stopped`/`failed`）になるまで待った
4. [ ] ECSサービスの`runningCount`が`desiredCount`まで自動復旧したことを確認した
5. [ ] CloudWatch Alarmの発火有無を確認した
6. [ ] 本テンプレートに結果を記録した
7. [ ] destroyは本演習では自動実行しない。継続して環境を使う場合を除き、別途`destroy.yml`の実行要否を判断する

## 結果記録

| 項目 | 結果 |
| --- | --- |
| 実験開始時刻（UTC） | |
| 実験終了時刻（UTC） | |
| 実験の終端ステータス（completed/stopped/failed） | |
| stop conditionで自動停止したか | Yes / No |
| ECSタスクの復旧に要した時間（停止検知〜runningCount回復） | |
| `nestjs-hannibal-3-ecs-task-stopped`アラーム発火 | Yes / No |
| `nestjs-hannibal-3-slo-error-rate-fast-burn`アラーム発火 | Yes / No |
| `nestjs-hannibal-3-slo-error-rate-slow-burn`アラーム発火 | Yes / No |
| `nestjs-hannibal-3-slo-response-time-fast-burn`アラーム発火 | Yes / No |
| `nestjs-hannibal-3-slo-response-time-slow-burn`アラーム発火 | Yes / No |
| CodeDeployのデプロイ状態への影響（canary/bluegreen中だった場合） | |
| 利用者影響（5xx増加、応答遅延等の有無） | |
| 想定外の挙動 | |

## 参考コマンド

```bash
PROJECT_NAME=nestjs-hannibal-3
REGION=ap-northeast-1

# ECSサービスの復旧確認
aws ecs describe-services \
  --cluster "${PROJECT_NAME}-cluster" \
  --services "${PROJECT_NAME}-api-service" \
  --region "$REGION"

# アラーム発火状況
aws cloudwatch describe-alarms \
  --alarm-name-prefix "$PROJECT_NAME" \
  --region "$REGION"

# FIS実験の詳細
aws fis get-experiment --id <experiment-id> --region "$REGION"
```

## 振り返り

- **うまく機能した点**:
- **改善が必要な点**:
- **runbook.md / SLO / IAMへのフィードバック**（該当があればIssue化する）:
