# 0029. AWS FIS実験テンプレートを独立root module `terraform/observability` に分離する

## ステータス

Accepted

## 日付

2026-07-07

## 決定内容

Game Day演習用のAWS FIS実験テンプレート（`terraform/modules/fis`、Issue #447で新設）を、`terraform/service`から独立した新しいroot module `terraform/observability` に分離する。

- `terraform/observability/`を新設し、`terraform/service`のremote stateから`ecs_cluster_name`/`ecs_service_name`/`slo_error_rate_fast_burn_alarm_arn`を参照して`module.fis`を呼び出す
- `.github/workflows/deploy.yml`に`Deploy Infrastructure (observability)`stepを追加し、`terraform/service`のapply後・`terraform/cdn`のapply前に配置する。`continue-on-error: true`とし、失敗しても後続のDockerビルド/push・CodeDeployデプロイ・cdn applyをブロックしない
- `.github/workflows/destroy.yml`にも対応する`Destroy Infrastructure (observability)`stepを追加し、`terraform/service`をdestroyする前に実行する。同様に`continue-on-error: true`とし、コスト影響のあるcdn/service/database/networkのdestroyをブロックしない
- `docs/operations/runbook.md`に、`deploy.yml`/`destroy.yml`が部分失敗した際のトラブルシューティング手順（ECSサービス状態の確認、terraform plan差分の確認、CodeDeployデプロイ履歴の確認、ALBリスナーとECS PRIMARY tasksetの整合性確認）を追記する

## 背景

Issue #447でGame Day演習用のFIS実験テンプレートを実装した際、`terraform/modules/fis`を`terraform/service`の一部として実装した（ADR-0028で「既存の全リソースがmodules化されている一貫性を優先」と判断）。

しかしIssue #454〜#456での実際のdeploy運用で、FIS実験テンプレートのIAM権限不備（`fis:CreateExperimentTemplate`の必須リソース権限の見落とし）が`terraform/service`の`terraform apply`全体を2回にわたって失敗させた。Terraformは部分失敗時にロールバックしないため、ALB/ECS/CodeDeployなど本体のコンテナデプロイに必須のリソースは正常に作成されていたにもかかわらず、`terraform apply`コマンド自体の異常終了により`deploy.yml`の`set -e`が働き、後続のDockerビルド/push・CodeDeployデプロイのステップが2回とも実行されなかった。

これは、カオスエンジニアリング機能（Game Day演習という付随的な検証手段）の設定ミスが、本番相当のコンテナデプロイ経路という無関係な処理をブロックしてしまう、blast radius（影響範囲）の分離不足である。ADR-0020は「responsibility ごとに root module を分ける」設計思想を既に採用しており、本ADRはその延長線上の判断である。

## 検討した選択肢

### 独立したroot module `terraform/observability` に分離する（採択）

- 長所: FIS実験テンプレートのapply失敗が、`terraform/service`のapply（ALB/ECS/CodeDeploy/monitoring）に一切影響しなくなる。blast radiusが完全に分離される
- 長所: ADR-0020の既存設計原則（責務ごとのroot module分割）に沿っており、一貫性がある
- 短所: root moduleが1つ増え、`terraform_remote_state`によるcross-module参照が追加される（`service` → `observability`の依存が新設される）
- 短所: deploy.yml/destroy.ymlのstep数が増え、workflow がやや複雑になる

### `terraform/service`内で`-target`を使った2段階apply にする

- 長所: root module追加が不要
- 短所: Terraform公式ドキュメントは`-target`の常用を推奨しておらず、CI/CDパイプラインでの定常運用には向かない
- 短所: 同一state内にリソースが混在する構造自体は変わらず、根本的なblast radius分離にはならない

### 現状維持（`terraform/service`内にFISを残す）

- 長所: 変更が不要
- 短所: 同様の障害が今後も本体デプロイをブロックし得る。個人ポートフォリオとしても「気づいたが直さなかった」状態になり、SRE原則（blast radius分離、部分失敗の影響局所化）を実践している証跡にならないと判断した

### `deploy.yml`のterraform applyステップ全体を`continue-on-error: true`にする

- 長所: 実装がシンプル
- 短所: ALB/ECS/CodeDeployなど本体の必須リソースの失敗まで握りつぶしてしまい、本当に必要な「本体は失敗させたいが付随機能は失敗を許容したい」という区別ができない。安全性が低下するため不採用

## 採択理由

Terraformの「部分失敗時に成功済みリソースはstateへ反映されるが、コマンド自体は失敗として扱われる」という性質を踏まえると、blast radiusの分離は「同じapply/destroyコマンドに含めるリソースの単位」でしか実現できない。ADR-0020の責務分割の原則（「一方を変えても他方に影響しないものを別stateにする」）に照らすと、FIS実験テンプレート（chaos engineering用の付随機能）とALB/ECS/CodeDeploy（本番相当のコンテナデプロイに必須）は明確に別の責務であり、同一root moduleに同居させる理由がない。

`continue-on-error: true`を`terraform/observability`のstepにのみ適用することで、「本体デプロイは従来どおり失敗时に停止する」という安全性を維持したまま、「付随機能の失敗が本体をブロックしない」という改善を両立できる。

## 影響

- `terraform/observability/`（新規root module）: `backend.tf`、`provider.tf`、`variables.tf`、`main.tf`、`outputs.tf`
- `terraform/service/main.tf`: `module "fis"`の呼び出しと関連local/dataソースを削除
- `terraform/service/outputs.tf`: `fis_experiment_template_id`を削除し、`slo_error_rate_fast_burn_alarm_arn`を追加（observabilityから参照するため）
- `.github/workflows/deploy.yml`: `Deploy Infrastructure (observability)`step（`continue-on-error: true`）と失敗時のJob Summary警告stepを追加
- `.github/workflows/destroy.yml`: `Destroy Infrastructure (observability)`step（`continue-on-error: true`）を追加
- `scripts/game-day/run-ecs-task-stop-experiment.sh`: FIS experiment template IDの参照元を`terraform/service`から`terraform/observability`に変更
- `docs/terraform-environments.md`、`docs/architecture/terraform-modules.md`、`CLAUDE.md`: root module一覧を6つに更新
- `docs/operations/runbook.md`: deploy.yml/destroy.yml部分失敗時のトラブルシューティング手順を追加
- コスト影響なし（既存FIS実験テンプレートリソースの移動のみ、新規AWSリソースは発生しない）
- `terraform/modules/fis`自体はディレクトリを移動せず、参照元root moduleのみ変更する

## 関連

- [Issue #447](https://github.com/kmryst/terraform-hannibal/issues/447)
- [Issue #454](https://github.com/kmryst/terraform-hannibal/issues/454)
- [Issue #456](https://github.com/kmryst/terraform-hannibal/issues/456)
- [Issue #458](https://github.com/kmryst/terraform-hannibal/issues/458)
- [ADR 0020: 環境 state を責務単位で分割する](./0020-split-environment-state-by-responsibility.md)
- [ADR 0028: AWS FISでECSタスク強制停止によるGame Day演習を自動化する](./0028-fis-game-day-ecs-task-stop-experiment-design.md)
- [Terraform 環境分離設計](../terraform-environments.md)
