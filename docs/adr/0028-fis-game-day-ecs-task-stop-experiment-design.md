# 0028. AWS FISでECSタスク強制停止によるGame Day演習を自動化する

## ステータス

Accepted

## 日付

2026-07-06

## 決定内容

Issue #447として、AWS FISでECSタスクを意図的に停止させ、ECS/CodeDeployの自動復旧とSLO burn-rateアラート（ADR-0026）の発火を検証するGame Day演習を以下の設計で自動化する。

- **target選択方式**: `aws:ecs:task`リソースタイプ、`parameters`（`cluster`/`service`）による選択、`selectionMode = COUNT(1)`。実行中タスクのうち1つだけをランダムに選び停止する
- **stop condition**: Issue #445で作成した`nestjs-hannibal-3-slo-error-rate-fast-burn`アラームをFISの`stop_condition`（`aws:cloudwatch:alarm`）に接続する。演習中に利用者影響が悪化した場合、FISが実験を自動停止する
- **Terraform配置**: `terraform/modules/fis`モジュールを新設し、`terraform/service/main.tf`から呼び出す。既存の`load-balancer`/`ecs`/`codedeploy`/`monitoring`と同じmodules化パターンに揃える
- **演習実行スクリプト**: `scripts/game-day/run-ecs-task-stop-experiment.sh`（bash）。既存`scripts/github/*.sh`と同じくshellcheck/shfmtのpre-commit対象。`destroy.yml`を含むいかなるGitHub Actions workflowもトリガーしない
- **結果記録テンプレート**: `docs/operations/game-day-exercise-template.md`。`docs/operations/`配下の運用ドキュメント群と並べ、`runbook.md`から参照する
- **IAM追加修正**: Issue #446で新設した`HannibalFISPolicy-Dev`/`HannibalFISBoundary-Dev`に、AWS FIS公式ドキュメントが`aws:ecs:stop-task`の必須権限として明記している`tag:GetResources`を追加する（#446時点で見落としていた不足分）

## 背景

Issue #446で`HannibalFISRole-Dev`とその実行権限（ECS DescribeTasks/ListTasks/DescribeClusters/StopTask）を用意済みだったが、AWS公式ドキュメント（[Amazon ECS actions - aws:ecs:stop-task](https://docs.aws.amazon.com/fis/latest/userguide/fis-actions-reference.html)）を#447の実装時に確認したところ、`tag:GetResources`も必須権限として明記されていることが判明した。これはFISがターゲット解決時にタグベースAPIを内部的に使用するためで、resource type固有のDescribe系権限だけでは不足する。

Game Day演習の対象ECSタスクをどう選ぶかについては、AWS FIS公式ドキュメントの「Tasks with the specified parameters」の例（`cluster`/`service`パラメータ + `COUNT(1)`）がそのまま実運用パターンとして提示されており、`resource_arns`や`resource_tag`を使わずに済む。

## 検討した選択肢

### target選択: `COUNT(1)` 固定数 vs `PERCENT(n)`割合

- **`COUNT(1)`（採択）**: dev環境の少数タスク構成（`desired_task_count`が小さい）では、割合指定は実質的に固定数と変わらず、意図が明確な固定数を採用する方が読み手にとって分かりやすい
- **`PERCENT(n)`**: 将来task数が増えた場合にスケールする設計だが、現時点でその必要性がなく、`n%が何タスクになるか`を計算する認知負荷が増えるだけ

### stop condition: burn-rateアラーム接続 vs なし

- **burn-rateアラーム接続（採択）**: Issue #445で作成した`slo-error-rate-fast-burn`をそのまま安全装置として再利用できる。演習という「意図的な障害注入」が、SLO監視の実効性を演習自体でも検証する二重の意味を持つ
- **stop conditionなし**: 実装は簡単だが、演習中に想定外の悪化があっても自動停止されず、手動対応に依存する

ただし、この安全装置はCodeDeployのcanary/bluegreen自動ロールバックとは目的が異なる。CodeDeployのロールバックは「デプロイ由来の悪化」を検知して対応するものであり、FISのstop conditionは「演習という注入された障害」が想定を超えて悪化した場合の非常停止である。両者を同一視しないよう、`runbook.md`に注記した。

### Terraformモジュール化 vs `terraform/service/main.tf`への直接記述

- **モジュール化（採択）**: 既存の全リソース（ALB、ECS、CodeDeploy、monitoring）がmodules化されており、一貫性を優先した。将来的にstaging相当の環境を追加する場合の再利用性もある
- **直接記述**: 再利用性が低い（FIS実験テンプレートは現状1環境1テンプレート）ため過剰設計になり得たが、既存パターンとの一貫性を優先した

### 演習結果記録テンプレートの配置: `docs/operations/` vs `scripts/game-day/`

- **`docs/operations/`（採択）**: SLO・runbook等の運用ドキュメント群と並び、`runbook.md`からのリンクが自然になる
- **`scripts/game-day/`**: スクリプトと同じ場所に置く案もあったが、`docs/`が運用記録の正本群であるという既存の構成と整合しない

## 採択理由

いずれの判断も、既存のこのリポジトリの設計パターン（modules化、`docs/operations/`への運用ドキュメント集約、bashスクリプトへのshellcheck/shfmt適用）を踏襲する方向で決定した。dev環境の小規模構成に対して過剰な複雑さ（`PERCENT`指定、composite alarm等）を避けつつ、Issue #445で構築したSLO burn-rateアラートを演習の安全装置として活用することで、両Issueの成果を組み合わせた設計にした。

## 影響

- `terraform/modules/fis/`（新規）: `aws_fis_experiment_template`
- `terraform/service/main.tf`: `data "aws_caller_identity" "current"`追加、`module "fis"`呼び出し追加
- `terraform/modules/monitoring/outputs.tf`: `slo_error_rate_fast_burn_alarm_arn`出力を追加
- `terraform/service/outputs.tf`: `fis_experiment_template_id`出力を追加
- `terraform/foundation/iam.tf`: `HannibalFISPolicy-Dev`/`HannibalFISBoundary-Dev`に`tag:GetResources`を追加（Issue #446の権限不足の是正）
- `scripts/game-day/run-ecs-task-stop-experiment.sh`（新規）
- `docs/operations/game-day-exercise-template.md`（新規）
- `docs/operations/runbook.md`: Game Day演習節を追加
- `scripts/README.md`: `game-day/`のエントリを追加
- コスト影響: FIS実験は$0.10/action程度。演習ごとのdeploy一式のコストは既存のdeploy/destroyサイクルと同等

**追記（2026-07-07、Issue #458）**: 本ADRでは「Terraformモジュール化」の判断として`terraform/modules/fis`を`terraform/service`から呼び出す設計を採択したが、実際の運用でFIS実験テンプレートのIAM権限不備が`terraform/service`のapply全体を繰り返しブロックする事態が発生した。ALB/ECS/CodeDeployという本体のコンテナデプロイ経路と、Game Day演習という付随機能のblast radiusを分離するため、`terraform/modules/fis`の呼び出し元を独立したroot module `terraform/observability` に切り出した。経緯と判断はADR-0029を参照。

## 関連

- [Issue #445](https://github.com/kmryst/terraform-hannibal/issues/445)
- [Issue #446](https://github.com/kmryst/terraform-hannibal/issues/446)
- [Issue #447](https://github.com/kmryst/terraform-hannibal/issues/447)
- [ADR 0026: ALB系SLIをCloudWatch metric mathで算出しSLO burn-rateアラートに接続する](./0026-slo-burn-rate-alerts-for-alb-slis.md)
- [ADR 0027: Game Day演習向けAWS FIS実行ロールをECSタスク停止のみに限定する](./0027-fis-iam-permission-boundary-for-game-day.md)
- [Runbook](../operations/runbook.md)
- [Game Day演習記録テンプレート](../operations/game-day-exercise-template.md)
