# Architecture Decision Records

このディレクトリは、`terraform-hannibal` の重要な設計判断を ADR（Architecture Decision Record）として残す場所です。

現在の仕様・構成・運用手順は、領域ごとに定められた正本に従います。
ADR はその正本を置き換えるものではなく、重要な設計判断の背景・採択理由・トレードオフ・再検討条件を記録するものです。

## 番号付け

- ファイル名は `NNNN-kebab-case-title.md` とする
- `NNNN` は 4 桁の連番とし、一度使った番号は再利用しない
- 番号は ADR ファイルを追加する PR の時点で、`docs/adr/` 配下の最大番号 + 1 として確定する。Issue / ブランチの段階では番号を予約しない
- supersede する場合も古い ADR は削除せず、新しい ADR から参照する

## 形式

各 ADR は少なくとも次の項目を含めます。

- `ステータス`
- `日付`
- `決定内容`
- `背景`
- `検討した選択肢`
- `採択理由`
- `影響`
- `関連`

### ステータスの語彙

- `Proposed` — 提案中。まだ採択されていない
- `Accepted` — 採択済み。現在有効な判断
- `Superseded` — 後続の ADR に置き換えられた（置き換え先 ADR を `関連` から参照する）
- `Deprecated` — 廃止。置き換え先はないが、もう採用しない

### 日付の扱い

`日付` は **ADR を記録した日**であり、元の判断が行われた時期とは限りません。
既存の判断を後から ADR 化（遡及記録）する場合は、元の判断時期は各 ADR の `関連` に挙げる Issue / PR を参照してください。

## 一覧

| ADR | ステータス | 決定 |
|---|---|---|
| [0001](./0001-disable-guardduty-for-cost.md) | Accepted | GuardDuty はコスト優先のため常時有効化しない |
| [0002](./0002-accept-waf-disabled-for-ephemeral-environment.md) | Accepted | WAF 無効化を ephemeral environment の accepted risk として扱う |
| [0003](./0003-migrate-terraform-state-locking-to-s3-lockfile.md) | Accepted | Terraform state locking は S3 lockfile を正とする |
| [0004](./0004-keep-internet-facing-alb-with-cloudfront-origin-controls.md) | Accepted | ALB は internet-facing のまま CloudFront 経由制限を追加する |
| [0005](./0005-separate-cicd-and-pr-plan-roles.md) | Accepted | deploy/destroy 用 Role と PR plan 用 Role を分離する |
| [0006](./0006-allow-read-prefix-wildcards-for-pr-plan-role.md) | Accepted | PR plan Role の read 系 wildcard を限定的に許容する |
| [0007](./0007-remove-unused-access-analyzer-permissions.md) | Accepted | 未使用の Access Analyzer / IAM read 権限を CICD Role から削除する |
| [0008](./0008-on-demand-startup-and-routine-destroy-operation.md) | Accepted | オンデマンド起動 / 通常 destroy 運用を採用する（コスト系判断の親前提） |
| [0009](./0009-keep-nestjs-hannibal-3-resource-names.md) | Accepted | 既存の AWS リソース名 nestjs-hannibal-3-* をリネームしない |
| [0010](./0010-adopt-lightweight-and-strict-github-flow.md) | Accepted | 軽運用 / 厳密運用を分ける GitHub Flow モデルを採用する |
| [0011](./0011-adopt-ecs-fargate-for-application-runtime.md) | Accepted | アプリケーション実行基盤に ECS Fargate を採用する |
| [0012](./0012-consolidate-iac-security-scan-on-trivy-config.md) | Accepted | IaC security scan を Trivy Config に集約し tfsec を新規採用しない |
| [0013](./0013-promote-quality-checks-to-required-gradually.md) | Accepted | 品質チェックを観察期間後に段階的 required 化する |
| [0014](./0014-separate-terraform-foundation-and-environment-state.md) | Accepted | Terraform foundation / environments のルートモジュールと state を分離する |
| [0015](./0015-adopt-codedeploy-blue-green-for-ecs-deployments.md) | Accepted | ECS デプロイに CodeDeploy Blue/Green を採用する |
| [0016](./0016-adopt-rds-postgresql-jsonb-over-aurora-and-postgis.md) | Accepted | RDS PostgreSQL + JSONB を採用し、Aurora / PostGIS はスコープ外とする |
| [0017](./0017-pin-github-actions-by-owner-tier.md) | Accepted | GitHub Actions の action 参照を owner tier で固定する（GitHub-owned は semver tag / 外部は SHA pin） |
| [0018](./0018-adopt-node24-and-supported-dependency-lines.md) | Accepted | Node.js 24とsupported dependency lineをapplication runtime / CI / containerへ採用する |
| [0019](./0019-adopt-pr-preview-environment-with-isolated-state.md) | Superseded | Terraform state を PR 単位で分離する Preview Environment を採用する |
| [0020](./0020-split-environment-state-by-responsibility.md) | Accepted | 環境 state を責務単位で分割する |
| [0021](./0021-pause-pr-terraform-plan-artifact.md) | Accepted | PR Terraform Plan Artifact を一時停止する |
| [0022](./0022-keep-prod-rds-on-t3-micro-until-metrics-justify-scale-up.md) | Accepted | prod RDS はメトリクスが引き上げを正当化するまで db.t3.micro に据え置く |
| [0023](./0023-adopt-mise-for-local-tooling-and-pre-commit-terraform-docs.md) | Accepted | ローカルツール管理に mise を採用し terraform-docs は pre-commit で運用する |
| [0024](./0024-use-pre-commit-and-ci-dual-layer-for-shell-dockerfile-lint.md) | Deprecated | シェルスクリプト / Dockerfile の lint を pre-commit と CI の二層で実行する |
| [0025](./0025-pin-github-actions-docker-images-by-tag-and-digest.md) | Accepted | GitHub Actions 内 Docker image を tag と digest で固定する |
| [0026](./0026-slo-burn-rate-alerts-for-alb-slis.md) | Accepted | ALB系SLIをCloudWatch metric mathで算出しSLO burn-rateアラートに接続する |
| [0027](./0027-fis-iam-permission-boundary-for-game-day.md) | Accepted | Game Day演習向けAWS FIS実行ロールをECSタスク停止のみに限定する |
| [0028](./0028-fis-game-day-ecs-task-stop-experiment-design.md) | Accepted | AWS FISでECSタスク強制停止によるGame Day演習を自動化する |
| [0029](./0029-separate-fis-observability-root-module-for-blast-radius.md) | Accepted | AWS FIS実験テンプレートを独立root module `terraform/observability` に分離する |
| [0030](./0030-adopt-cloudwatch-synthetics-canary-for-user-journey-monitoring.md) | Accepted | ユーザージャーニーレベルの外形監視にCloudWatch Synthetics canaryを採用する |
