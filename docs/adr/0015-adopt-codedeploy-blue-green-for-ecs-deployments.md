# 0015. ECS デプロイに CodeDeploy Blue/Green を採用する

## ステータス

Accepted

## 日付

2026-06-04

## 決定内容

`terraform-hannibal` のバックエンド API デプロイは、ECS service の rolling update や recreate ではなく、CodeDeploy の ECS Blue/Green deployment controller を採用する。

ECS service は `deployment_controller { type = "CODE_DEPLOY" }` とし、CodeDeploy deployment group は `deployment_style` を `BLUE_GREEN` / `WITH_TRAFFIC_CONTROL` にする。ALB には production listener と test listener、blue / green target group pair を用意し、CodeDeploy が新しい task set の作成、target group への紐付け、traffic 切り替え、旧 task set の終了を管理する。

デプロイの切り替え方式は二層の変数で表す。`deploy.yml` の workflow input である `deployment_mode` が `canary` / `bluegreen` / `provisioning` の運用モードを選び、Terraform var の `deployment_type`（`canary` / `bluegreen`）が CodeDeploy deployment config を決める。`provisioning` は `deployment_mode` 側だけの値で、その場合 workflow は `deployment_type=canary` に変換して基盤を作る。

`deployment_type = "bluegreen"` では `CodeDeployDefault.ECSAllAtOnce` により Blue / Green を即時切り替え、`deployment_type = "canary"` では `CodeDeployDefault.ECSCanary10Percent5Minutes` により 10% から 100% へ段階的に切り替える。どちらも CodeDeploy の Blue/Green deployment style を使う。`deployment_mode = "provisioning"` は初期構築用で、Terraform apply により基盤を作成し、CodeDeploy deployment step は実行しない。

この ADR は、すでに実装済みの構成を遡及的に記録するものであり、Terraform の現行設定や deploy workflow を変更するものではない。

## 背景

このプロジェクトは、React フロントエンド、NestJS / GraphQL API、RDS PostgreSQL を持つ AWS 上の 3 層 Web アプリケーションである。API は ECS Fargate task として private subnet で動作し、CloudFront / ALB 経由で request を受ける。

dev 環境は本番サービスではなく、通常 destroy 済みで必要時だけ deploy するオンデマンド運用である。一方で、ポートフォリオ / デモ用途として、単にアプリを起動できるだけではなく、AWS 上で実運用に近いデプロイ方式、traffic 切り替え、rollback、監視を Terraform と GitHub Actions で再現できることに価値がある。

デプロイ方式には、次の要件があった。

- backend / frontend の品質確認は PR gate に寄せ、merge 後の `deploy.yml` は main から手動実行する
- 新しい API image を ECR に push し、task definition revision と AppSpec を使って ECS service を更新する
- 利用者 traffic を受けている task set と、新しい task set を分けて扱える
- 失敗時は CodeDeploy failure または CloudWatch Alarm により rollback できる
- 初期構築時は Terraform apply だけで基盤を作り、通常デプロイ時は CodeDeploy で application revision を切り替える
- Terraform が管理する ALB listener rule と、CodeDeploy が一時的に変更する traffic routing が競合しない

## 検討した選択肢

### CodeDeploy ECS Blue/Green（採択）

- 長所: 現行 task set と新 task set を分離し、target group pair と listener route で traffic を制御できる
- 長所: `bluegreen` は短時間の all-at-once 切り替え、`canary` は 10% 検証後の段階切り替えとして同じ基盤で扱える
- 長所: CodeDeploy の deployment status、auto rollback、CloudWatch Alarm 連携により、失敗時の戻し方が明確になる
- 長所: production listener と test listener を分けられ、ECS / ALB / CodeDeploy を使う実運用に近い構成を示せる
- 短所: CodeDeploy application / deployment group、service role、artifact S3 bucket、blue / green target group、AppSpec 生成などの構成要素が増える
- 短所: デプロイ中は一時的に新旧 task set が並行し、短時間ではあるが Fargate task の重複コストが発生する
- 短所: Terraform 管理の listener rule action と CodeDeploy の動的変更が競合しないよう、`ignore_changes` などの境界を意識する必要がある

### ECS rolling update

- 長所: ECS service の標準機能であり、CodeDeploy application / deployment group や AppSpec を追加せずに済む
- 長所: Terraform または ECS service update で task definition revision を差し替えるだけなので、構成が軽い
- 短所: Blue / Green の target group pair や test listener を使った traffic 切り替えを表現しにくい
- 短所: 新旧 task set を明確に分けた deployment status と rollback を CodeDeploy ほど一元管理できない
- 短所: このプロジェクトが示したい CodeDeploy ECS Blue/Green / Canary のデモ価値が失われる

### recreate / provisioning-only

- 長所: 既存 service を停止して作り直す、または毎回 `provisioning` で再構築するだけなら、実装は単純になる
- 長所: dev 環境を通常 destroy 済みにする運用とは相性がよく、常時 traffic を前提にしない場合は割り切りやすい
- 短所: 起動済み環境に対する通常デプロイでは downtime が発生し、無停止切り替えや段階的検証を示せない
- 短所: 失敗時の戻し方が GitHub Actions / Terraform / 手動手順に散り、deployment 単位の rollback として追跡しにくい
- 短所: image 更新のたびに環境再作成へ寄せると、RDS / ALB / CloudFront など周辺リソースまで巻き込む運用ノイズが増える

### GitHub Actions による自前 ALB 切り替え

- 長所: CodeDeploy を使わず、AWS CLI で target group や listener rule を直接切り替えることで、細かい制御はできる
- 短所: deployment state、rollback、alarm integration、task set lifecycle を自前で実装する必要がある
- 短所: GitHub Actions の shell script に release orchestration が集中し、Terraform / ECS / ALB / 監視の責務境界が曖昧になる
- 短所: 少人数運用では、AWS managed service に任せられる部分まで自前で保守する負担が大きい

## 採択理由

CodeDeploy ECS Blue/Green は、ECS Fargate で動く NestJS API を保ちながら、ALB target group pair を使って traffic を制御できる。現行 task set と新 task set を分離できるため、単なる task definition 更新ではなく、deployment 単位で状態、失敗、rollback を扱える。

`bluegreen` の all-at-once 切り替えは、dev / demo 環境で短時間に新 version を反映したい場合に向いている。`canary` は 5xx と response time の CloudWatch Alarm を見ながら 10% から 100% へ進められるため、変更リスクがある場合の検証ルートとして使える。どちらも同じ CodeDeploy deployment group と Blue/Green infrastructure の上に乗るため、運用説明を分けすぎずに済む。

Terraform は target group、listener、ECS service、CodeDeploy deployment group などの静的な基盤を管理し、GitHub Actions は image build、task definition registration、AppSpec 生成、CodeDeploy deployment 開始を担う。CodeDeploy は deployment 中の task set と listener route の変更を担う。この分担により、Terraform apply と application deployment を混ぜすぎず、PR gate 通過後の main 手動 deploy という運用に収まる。

rolling update は構成が軽いが、Blue / Green target group、test listener、canary、auto rollback を含むデプロイ設計を示す価値が下がる。recreate はさらに単純だが、起動済み環境への通常デプロイでは downtime と復旧手順の粗さが残る。自前 ALB 切り替えは制御性があるものの、CodeDeploy が提供する deployment state と rollback を再実装することになり、少人数の dev 中心運用には重い。

したがって、このプロジェクトでは、多少の構成要素と一時的な重複 task cost を許容し、CodeDeploy ECS Blue/Green を採用する。コスト面の残余リスクは [0008](./0008-on-demand-startup-and-routine-destroy-operation.md) のオンデマンド起動 / 通常 destroy 運用で抑える。

## 影響

- ECS service は `CODE_DEPLOY` deployment controller を前提にするため、通常の ECS rolling update とは更新手順が異なる
- deploy workflow は ECR image push、task definition registration、AppSpec 生成、S3 artifact upload、CodeDeploy deployment start を行う必要がある
- ALB は production listener / test listener と blue / green target group pair を持つ
- CodeDeploy は `DEPLOYMENT_FAILURE` と `DEPLOYMENT_STOP_ON_ALARM` で auto rollback する
- `bluegreen` と `canary` は deployment config が異なるが、どちらも Blue/Green deployment style 上で動く
- `provisioning` は初期構築用であり、CodeDeploy deployment step を実行しない
- デプロイ中は一時的に新旧 task set が並行し、短時間の Fargate task 重複コストが発生する
- Terraform と CodeDeploy の境界は `ignore_changes` で管理する。ECS service は `ignore_changes = [task_definition, load_balancer]` で、CodeDeploy が切り替えた task definition revision と target group を Terraform apply が巻き戻さないようにする。ALB listener rule は `ignore_changes = [action]` で、CodeDeploy の動的な traffic weight 変更を許容する
- rolling update や recreate へ移行する場合は、ECS service deployment controller、CodeDeploy module、deploy workflow、rollback runbook をまとめて見直す必要がある
- この ADR 自体は docs-only であり、新しい AWS リソースやコストは発生しない

## 関連

- [Issue #303](https://github.com/kmryst/terraform-hannibal/issues/303)
- [docs/deployment/codedeploy-blue-green.md](../deployment/codedeploy-blue-green.md) - ECS CodeDeploy Blue/Green / Canary の現行設計
- [docs/operations/monitoring.md](../operations/monitoring.md) - deploy workflow、CodeDeploy status、canary alarm の監視
- [docs/operations/runbook.md](../operations/runbook.md) - CodeDeploy 失敗時の auto rollback / 手動 rollback
- [docs/architecture/system-design.md](../architecture/system-design.md) - 運用設計と CI/CD の全体像
- [.github/workflows/deploy.yml](../../.github/workflows/deploy.yml) - provisioning / bluegreen / canary の deploy workflow

CodeDeploy / ALB / ECS module や target group pair・listener・`ignore_changes` 境界の Terraform 実装は、正本である [codedeploy-blue-green.md](../deployment/codedeploy-blue-green.md) を起点に追う（module パスの直リンクは refactor で腐りやすいため ADR には固定しない）。

- [0008](./0008-on-demand-startup-and-routine-destroy-operation.md) - オンデマンド起動 / 通常 destroy 運用
- [0011](./0011-adopt-ecs-fargate-for-application-runtime.md) - アプリケーション実行基盤に ECS Fargate を採用する
