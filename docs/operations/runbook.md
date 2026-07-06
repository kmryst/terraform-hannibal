# Runbook

この Runbook は、CloudWatch Alarm またはデプロイ失敗を受けた時の初動手順をまとめる。
AWS CLI 例では `ap-northeast-1` と `nestjs-hannibal-3` を前提にする。
コマンド出力に secret や credential が含まれる可能性がある場合は、値を貼り付けずに状態だけ共有する。

Terraform の `init` / `plan` / `apply` / state lock / import / drift 確認は [Terraform Runbook](./terraform-runbook.md) を参照する。
Terraform apply 失敗、誤変更、state 復元の戻し方は [Terraform Rollback Plan](./rollback-plan.md) を参照する。

## 共通初動

1. 通知された alarm 名、発生時刻、AWS region を確認する。
2. CloudWatch Alarm の現在状態を確認する。
3. 直近で GitHub Actions の `deploy.yml`、Terraform apply、CodeDeploy が動いていなかったか確認する。
4. 利用者影響がある場合は、ALB 5xx、TargetResponseTime、ECS running count、ECS logs を優先して見る。
5. デプロイ直後の悪化であれば、CodeDeploy の auto rollback または手動 rollback を優先する。

共通確認コマンド:

```bash
PROJECT_NAME=nestjs-hannibal-3
REGION=ap-northeast-1
CLUSTER="${PROJECT_NAME}-cluster"
SERVICE="${PROJECT_NAME}-api-service"
LOG_GROUP="/ecs/${PROJECT_NAME}-api-task"

aws cloudwatch describe-alarms \
  --alarm-name-prefix "$PROJECT_NAME" \
  --region "$REGION"

aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --region "$REGION"

aws logs tail "$LOG_GROUP" \
  --since 30m \
  --region "$REGION"
```

## CloudWatch Alarm 対応

| Alarm                                                     | 主な意味                                     | 初動                                                                 |
| --------------------------------------------------------- | -------------------------------------------- | -------------------------------------------------------------------- |
| `nestjs-hannibal-3-ecs-cpu-high`                          | ECS CPU 5分平均が 70% 超過                   | traffic 増加、無限ループ、直近 deploy を確認する                     |
| `nestjs-hannibal-3-ecs-memory-high`                       | ECS memory 5分平均が 75% 超過                | memory leak、OOM kill、直近 deploy を確認する                        |
| `nestjs-hannibal-3-ecs-task-stopped`                      | ECS task 停止または running count 異常の疑い | ECS service と stopped task reason を確認する                        |
| `nestjs-hannibal-3-rds-cpu-high`                          | RDS CPU 5分平均が 60% 超過                   | slow query、接続増加、アプリ retry を確認する                        |
| `nestjs-hannibal-3-rds-connections-high`                  | RDS connections が 12 超過                   | connection leak、pool 設定、再試行増加を確認する                     |
| `nestjs-hannibal-3-slo-response-time-fast-burn`           | 応答時間SLI(平均/SLO目標比)が5分でSLO目標の2倍超過 | ECS/RDS/外部依存の遅延を切り分ける                                   |
| `nestjs-hannibal-3-slo-response-time-slow-burn`           | 応答時間SLIが30分持続でSLO目標の1.2倍超過    | ECS/RDS/外部依存の遅延を切り分ける                                   |
| `nestjs-hannibal-3-slo-error-rate-fast-burn`               | 5xx rate SLI(ratio)が5分でerror budgetの14.4倍超過 | ECS logs と直近 deploy を確認する                                    |
| `nestjs-hannibal-3-slo-error-rate-slow-burn`               | 5xx rate SLIが30分持続でerror budgetの3倍超過 | ECS logs と直近 deploy を確認する                                    |
| `nestjs-hannibal-3-canary-error-rate`                     | canary 中の 5xx 増加                         | CodeDeploy auto rollback の状態を確認する                            |
| `nestjs-hannibal-3-canary-response-time`                  | canary 中の response time 悪化               | CodeDeploy auto rollback の状態を確認する                            |
| `nestjs-hannibal-3-cloudtrail-root-account-usage`         | root account 利用検知                        | 正当性確認、不要なら認証情報保護と MFA 確認を行う                    |
| `nestjs-hannibal-3-cloudtrail-iam-policy-change`          | IAM policy 変更検知                          | 変更者、変更内容、Issue / PR との対応を確認する                      |
| `nestjs-hannibal-3-cloudtrail-configuration-change`       | CloudTrail 設定変更検知                      | 監査ログ停止や改ざん意図がないか確認する                             |
| `nestjs-hannibal-3-cloudtrail-console-signin-without-mfa` | MFA なし console login 検知                  | 対象 principal を確認し、MFA 有効化と credential rotation を検討する |

### ECS CPU high

1. ECS service の `runningCount` / `desiredCount` と deployment 状態を確認する。
2. CloudWatch Logs で error や同じ処理の連続実行がないか確認する。
3. ALB `RequestCount` と `TargetResponseTime` が同時に増えているか確認する。
4. 直近 deploy 後に発生した場合は CodeDeploy rollback を検討する。
5. 継続的な負荷であれば、task CPU 増加または desired count 増加を Terraform 変更として Issue 化する。

```bash
aws ecs describe-services \
  --cluster nestjs-hannibal-3-cluster \
  --services nestjs-hannibal-3-api-service \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount,deployments:deployments}' \
  --region ap-northeast-1
```

### ECS memory high

1. CloudWatch Logs で OOM、GC、同一リクエストの再試行を確認する。
2. stopped task がある場合は `stoppedReason` と container の `reason` を確認する。
3. 直近 deploy で増えた場合は前バージョンへの rollback を優先する。
4. 継続的な増加であれば memory leak 調査 Issue を作る。

### ECS task stopped

ECS task 停止時は alarm 名だけで判断せず、ECS service の desired / running count と stopped task reason を正本にする。

1. service の `runningCount` が `desiredCount` を下回っているか確認する。
2. 直近停止した task ARN を取得する。
3. `stoppedReason`、container `exitCode`、container `reason` を確認する。
4. ECS logs で停止直前の error を確認する。
5. よくある原因として、Secrets Manager 参照不可、ECR image pull 失敗、NAT 経路不備、RDS 接続失敗、memory 不足を確認する。

```bash
TASKS=$(aws ecs list-tasks \
  --cluster nestjs-hannibal-3-cluster \
  --service-name nestjs-hannibal-3-api-service \
  --desired-status STOPPED \
  --max-results 5 \
  --query 'taskArns' \
  --output text \
  --region ap-northeast-1)

aws ecs describe-tasks \
  --cluster nestjs-hannibal-3-cluster \
  --tasks $TASKS \
  --query 'tasks[*].{task:taskArn,stoppedReason:stoppedReason,containers:containers[*].{name:name,exitCode:exitCode,reason:reason}}' \
  --region ap-northeast-1
```

### RDS CPU / connections high

1. ECS logs で DB timeout、connection refused、retry storm がないか確認する。
2. RDS `CPUUtilization` と `DatabaseConnections` が同時に増えているか確認する。
3. deploy 後に発生した場合はアプリ変更起因を疑い、rollback を検討する。
4. connections だけが高い場合は connection pool 解放漏れや retry 設定を確認する。
5. 継続する場合は query 調査、index、pool 上限、DB instance class 見直しを Issue 化する。

### 応答時間SLI burn-rate（fast/slow burn）

`nestjs-hannibal-3-slo-response-time-fast-burn` / `nestjs-hannibal-3-slo-response-time-slow-burn` は、CloudWatch metric mathで算出した「平均TargetResponseTime / SLO目標(1秒)」の比率を見る。fast burnは短時間の急激な悪化、slow burnは持続的な悪化を検知する。設計判断は [ADR-0026](../adr/0026-slo-burn-rate-alerts-for-alb-slis.md) を参照。

1. ALB `TargetResponseTime`、`HTTPCode_Target_5XX_Count`、ECS CPU / memory、RDS CPU / connections を同じ時間帯で見る。
2. ECS / RDS のどちらも正常なら、アプリケーションログで遅い endpoint や GraphQL query を確認する。
3. canary / bluegreen 中なら CodeDeploy の alarm と deployment status を確認する。
4. 利用者影響が継続する場合は rollback を優先する。
5. fast burnのみ発報している場合は短時間のスパイクの可能性があるため、slow burnの発報有無で持続性を確認する。

### 5xx rate SLI burn-rate（fast/slow burn）

`nestjs-hannibal-3-slo-error-rate-fast-burn` / `nestjs-hannibal-3-slo-error-rate-slow-burn` は、CloudWatch metric mathで算出した「5xx count / RequestCount」のratio(%)を見る。5分間のリクエスト数が少ない場合はratioを0%扱いにする低トラフィックガードがある（[ADR-0026](../adr/0026-slo-burn-rate-alerts-for-alb-slis.md)参照）。

1. ECS logs で exception、DB 接続エラー、起動失敗を確認する。
2. ALB target health を確認し、unhealthy target が増えていないか見る。
3. 直近 deploy がある場合は CodeDeploy deployment status を確認する。
4. canary 中の 5xx であれば auto rollback を待つ。止まらない場合は手動停止する。
5. 低トラフィック時（リクエスト数が少ない時間帯）はratioが0%扱いになり発報しないことがあるため、絶対数（`HTTPCode_Target_5XX_Count`）も合わせて確認する。

```bash
for tg in nestjs-hannibal-3-blue-tg nestjs-hannibal-3-green-tg; do
  TG_ARN=$(aws elbv2 describe-target-groups \
    --names "$tg" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text \
    --region ap-northeast-1 2>/dev/null) || continue
  echo "=== $tg ==="
  aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[*].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
    --region ap-northeast-1
done
```

```bash
aws deploy list-deployments \
  --application-name nestjs-hannibal-3-app \
  --deployment-group-name nestjs-hannibal-3-dg \
  --max-items 5 \
  --region ap-northeast-1
```

### Canary alarms

`nestjs-hannibal-3-canary-error-rate` または `nestjs-hannibal-3-canary-response-time` が ALARM になった場合、CodeDeploy は `DEPLOYMENT_STOP_ON_ALARM` で auto rollback する設定になっている。

1. CodeDeploy deployment status を確認する。
2. `Stopped` / `Failed` / `Succeeded` のどれかを確認する。
3. rollback が進んでいる場合は完了まで待ち、ALB 5xx と response time が戻るか確認する。
4. rollback しない場合は `stop-deployment --auto-rollback-enabled` を実行する。

```bash
DEPLOYMENT_ID=<deployment-id>

aws deploy get-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --region ap-northeast-1

aws deploy stop-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --auto-rollback-enabled \
  --region ap-northeast-1
```

### CloudTrail security alarms

CloudTrail security alarm は、利用者影響よりも監査性と権限保護を優先して扱う。

1. CloudTrail Event history または CloudWatch Logs `/aws/cloudtrail/nestjs-hannibal-3` で対象 event を確認する。
2. 変更者、source IP、eventName、userAgent を確認する。
3. 対応する Issue / PR / GitHub Actions run があるか確認する。
4. 正当な変更でなければ、該当 credential の無効化、MFA 状態確認、権限見直しを行う。
5. CloudTrail 停止や IAM policy 変更が不審な場合は、以降の deploy / apply を止めて調査を優先する。

## デプロイ失敗時の rollback

### 自動 rollback

CodeDeploy deployment group は次の event で auto rollback する。

- `DEPLOYMENT_FAILURE`
- `DEPLOYMENT_STOP_ON_ALARM`

まずは CodeDeploy の状態を確認する。

```bash
aws deploy list-deployments \
  --application-name nestjs-hannibal-3-app \
  --deployment-group-name nestjs-hannibal-3-dg \
  --max-items 5 \
  --region ap-northeast-1

aws deploy get-deployment \
  --deployment-id <deployment-id> \
  --region ap-northeast-1
```

### 手動 rollback

自動 rollback が進まない、または利用者影響が継続している場合は、進行中 deployment を止める。

```bash
aws deploy stop-deployment \
  --deployment-id <deployment-id> \
  --auto-rollback-enabled \
  --region ap-northeast-1
```

前バージョンを明示的に戻す必要がある場合は、前回成功した task definition または AppSpec を使って再 deployment する。
GitHub Actions 由来の変更なら、原因 commit を revert して PR 経由で戻す。

```bash
git revert <commit-sha>
git push origin <branch>
```

rollback 後は次を確認する。

- CodeDeploy deployment が `Succeeded` になっている
- ECS service の `runningCount` が `desiredCount` と一致している
- ALB 5xx が止まっている
- `TargetResponseTime` が SLO 範囲に戻っている
- ECS logs に同じ error が出続けていない

## 復旧後

1. 発生時刻、検知した alarm、利用者影響、原因、暫定対応、恒久対応を Issue または PR に記録する。
2. 同じ alarm が繰り返される場合は、閾値調整ではなく先に原因を調査する。
3. Terraform / workflow / script の変更が必要な場合は、通常の Issue -> Branch -> PR の流れで対応する。

## Game Day演習（AWS FISによるECSタスク強制停止）

AWS FISでECSタスクを意図的に停止させ、ECS/CodeDeployの自動復旧、CloudWatch Alarm・SLO burn-rateアラートの発火、runbookの実効性を検証する演習(Issue #447)。

前提: `terraform/foundation`の`HannibalFISRole-Dev`/`HannibalFISBoundary-Dev`(Issue #446)がapply済みであること、`terraform/service`と`terraform/observability`(FIS実験テンプレート。本体デプロイからblast radiusを分離した独立root module、Issue #458)がdeploy済みであること。

### サイクル

1. **deploy**: `deploy.yml`（`canary`または`bluegreen`）で環境をデプロイする。`terraform/observability`は本体（network/database/service/cdn）とは独立したstepとして`continue-on-error: true`で適用され、失敗しても本体デプロイはブロックされない
2. **演習実施**: `./scripts/game-day/run-ecs-task-stop-experiment.sh`を実行する
   - AWS FISが`nestjs-hannibal-3-cluster`の実行中タスクから1つ（`COUNT(1)`）を選び`StopTask`する
   - `nestjs-hannibal-3-slo-error-rate-fast-burn`アラームをstop conditionとして接続しており、演習中に利用者影響が悪化した場合はFISが実験を自動停止する
   - スクリプトは実験が終端状態になるまでポーリングし、ECSサービス確認・アラーム確認の次のコマンドを表示する
3. **結果記録**: [game-day-exercise-template.md](./game-day-exercise-template.md)に復旧時間・アラーム発火有無を記録する
4. **destroy**: 演習用に環境を維持する必要がなければ、`destroy.yml`を実行する。**演習スクリプトは`destroy.yml`を自動トリガーしない**。destroyの実行は常に人間が判断する。`terraform/observability`はserviceより先にdestroyされ、ここも`continue-on-error: true`で本体destroyをブロックしない

### deploy.yml/destroy.yml 部分失敗時のトラブルシューティング

`terraform apply`/`destroy`は失敗しても、それ以前に成功したリソース作成・変更はstateに残る（terraformはトランザクショナルなロールバックをしない）。GitHub Actionsの`set -e`によりjobはそこで停止するため、後続のDockerビルド/push・CodeDeployデプロイが**未実行のまま**deploy.yml自体は失敗扱いになることがある(Issue #454〜#458で実際に発生)。再実行前に次を確認する。

1. **ECSサービスの状態を確認する**（`provisioning`を使うべきか`canary`/`bluegreenを使うべきかの判断材料）

   ```bash
   aws ecs describe-services \
     --cluster nestjs-hannibal-3-cluster \
     --services nestjs-hannibal-3-api-service \
     --region ap-northeast-1 \
     --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'
   ```

   - `ClusterNotFoundException`または`services`が空 → `provisioning`を使う（初回構築）
   - `status: ACTIVE`（`running`が0でも） → `deploy.yml`のガードで`provisioning`は使えない。`canary`または`bluegreen`を使う（新しいタスク定義とコンテナイメージで再デプロイされ、不完全な状態も解消される）

2. **terraform stateと実環境の整合性を確認する**（孤立したリソースが残っていないか）

   ```bash
   terraform -chdir=terraform/service plan -input=false \
     -var="client_url_for_cors=https://hamilcar-hannibal.click" \
     -var="environment=dev" \
     -var="deployment_type=canary" \
     -var="ecr_repository_url=<ECR_REPOSITORY_URL>" \
     -var="alb_certificate_arn=<ALB_CERTIFICATE_ARN>" \
     -var="db_name=nestjs_hannibal_db"
   ```

   `No changes`であれば、失敗した実行が中途半端なリソースを残していないことを意味する（terraformの部分適用がstateに正しく反映されている）。

3. **CodeDeployのデプロイ履歴を確認する**（本当に新しいデプロイが実行されたか）

   ```bash
   aws deploy list-deployments \
     --application-name nestjs-hannibal-3-app \
     --deployment-group-name nestjs-hannibal-3-dg \
     --max-items 5 \
     --region ap-northeast-1
   ```

   terraform apply段階で失敗した実行は、CodeDeployのステップまで到達していないため、デプロイ履歴に記録が残らない。

4. **ALBリスナーのdefault_actionとECS PRIMARY tasksetの整合性を確認する**（Issue #380関連）

   ```bash
   aws elbv2 describe-listeners --load-balancer-arn <ALB_ARN> --query 'Listeners[?Port==`443`].DefaultActions'
   aws ecs describe-services --cluster nestjs-hannibal-3-cluster --services nestjs-hannibal-3-api-service \
     --query 'services[0].taskSets[*].{status:status,targetGroup:loadBalancers[0].targetGroupArn}'
   ```

   両者が指すtarget group（blue/green）が一致していることを確認する。

### 演習チェックリスト

- [ ] ECS serviceの`runningCount`が`desiredCount`まで自動復旧した（デプロイメントスケジューラによる再作成）
- [ ] `nestjs-hannibal-3-ecs-task-stopped`アラームが発火した
- [ ] `nestjs-hannibal-3-slo-error-rate-fast-burn`/`-slow-burn`、`nestjs-hannibal-3-slo-response-time-fast-burn`/`-slow-burn`アラームの発火有無を確認した（Issue #445実装済みの場合）
- [ ] canary/bluegreenデプロイ中に実施した場合、CodeDeployのデプロイ状態への影響を確認した
- [ ] 想定外の挙動（復旧しない、アラームが発火しない等）があれば、原因調査Issueを作る

### 安全設計

- FIS実験テンプレートの対象は`COUNT(1)`固定で、常に1タスクのみを停止する
- `stop_condition`にSLO error-rate fast-burnアラームを接続しており、演習が意図せず悪化した場合は自動停止する（ただしCodeDeployのcanary/bluegreen自動ロールバックとは別系統の安全装置であり、両者を混同しない。詳細はADR-0028参照）
- 演習スクリプトは`destroy.yml`を含むいかなるGitHub Actions workflowもトリガーしない
