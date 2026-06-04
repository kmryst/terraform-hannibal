# 0011. アプリケーション実行基盤に ECS Fargate を採用する

## ステータス

Accepted

## 日付

2026-06-04

## 決定内容

`terraform-hannibal` のバックエンド API 実行基盤は、EC2 上のコンテナ実行や Lambda ではなく、ECS Fargate を採用する。

NestJS / GraphQL API は ECR のコンテナイメージとして管理し、`terraform/modules/compute/ecs` の ECS service / task definition で実行する。タスクは app private subnet に配置し、`assign_public_ip = false`、`awsvpc` network mode、ALB target group 経由の通信、CloudWatch Logs、Secrets Manager からの DB 認証情報注入を前提にする。

dev 環境の初期構成は、コスト最適化のため `desired_task_count = 1`、`cpu = 256`、`memory = 512` とする。デプロイ方式は CodeDeploy の ECS Blue/Green / Canary と組み合わせ、production listener / test listener と blue / green target group で task set を切り替える。

この ADR は、すでに実装済みの構成を遡及的に記録するものであり、Terraform の現行設定や運用手順を変更するものではない。

## 背景

このプロジェクトは、React フロントエンド、NestJS / GraphQL API、PostgreSQL と地理データのデータ層を持つ 3 層 Web アプリケーションである。フロントエンドは S3 / CloudFront で静的配信できるが、API は RDS へ接続し、ALB 経由で継続的な HTTP request を受けるアプリケーション実行基盤が必要になる。

また、このリポジトリはポートフォリオ / デモ用途の dev 環境であり、常時大量 traffic を処理することよりも、次の性質を重視する。

- VPC、private subnet、ALB、RDS、Secrets Manager、CloudWatch Logs を含む AWS 上の実運用に近い構成を IaC で再現できること
- Docker 化した NestJS API をそのまま実行できること
- CodeDeploy Blue/Green / Canary による無停止デプロイの構成を示せること
- 通常 destroy 済み、必要時だけ deploy する運用と相性がよいこと
- EC2 instance の OS / AMI / capacity / patch 管理を増やさないこと

Lambda は待機コストの面では魅力があるが、長時間起動する HTTP API、RDS 接続、ALB / CodeDeploy ECS Blue/Green、既存 Docker image pipeline との整合を考えると、アプリケーションの形を Lambda 向けに寄せる必要が大きい。

EC2 は制御性が高い一方で、instance 管理、Auto Scaling Group、容量設計、AMI / patch、host security など、デモ用途の API 実行基盤としては運用面の重さが先に立つ。

## 検討した選択肢

### ECS Fargate（採択）

- 長所: EC2 host を管理せずにコンテナを実行でき、NestJS API の Docker image と自然に接続できる
- 長所: task ごとに ENI / security group / IAM / logs / secrets を扱え、ALB -> ECS -> RDS の 3 層構成を private subnet 上で表現しやすい
- 長所: CodeDeploy の ECS Blue/Green / Canary と相性がよく、target group 切り替えによるデプロイ設計を示せる
- 長所: dev では 0.25 vCPU / 0.5 GB の最小構成にでき、通常 destroy 運用で待機コストを抑えられる
- 短所: 起動中は Fargate task、ALB、NAT Gateway、RDS などのコストが発生する
- 短所: Lambda と比べると request がない時間も task 実行コストが発生する
- 短所: EC2 と比べると host level の細かい制御や特殊な daemon 配置はできない

### ECS on EC2 / EC2 Auto Scaling

- 長所: instance type、AMI、host daemon、capacity 予約などを細かく制御できる
- 長所: 高い稼働率で複数 task を集約できる場合は、Fargate より費用最適化しやすい可能性がある
- 短所: EC2 instance、AMI、OS patch、capacity、Auto Scaling Group、ECS capacity provider の運用が増える
- 短所: dev 中心・オンデマンド起動の環境では、host 管理の学習価値より運用ノイズと誤設定リスクが大きい
- 短所: instance 起動後の余剰 capacity を持ちやすく、最小構成の API には過剰になりやすい

### Lambda / API Gateway

- 長所: request 単位課金に寄せやすく、待機コストを小さくできる
- 長所: サーバ管理が不要で、短い処理の API には向いている
- 短所: NestJS / GraphQL API を長時間起動するコンテナ service として扱う現在の設計から外れ、handler 化、cold start、connection pooling、VPC 接続の考慮が増える
- 短所: ALB target group と ECS task set を使う CodeDeploy Blue/Green / Canary の実証価値を失う
- 短所: RDS 接続を持つ API としては、接続管理や cold start の影響を別途設計する必要がある

## 採択理由

ECS Fargate は、既存の NestJS / GraphQL API をコンテナとして動かす形を保ちながら、EC2 host 管理を避けられる。private subnet に task を置き、ALB から security group で限定した内部 HTTP に流し、RDS へ接続する 3 層構成を、Terraform module として読みやすく表現できる。

また、CodeDeploy の ECS Blue/Green / Canary と組み合わせられるため、このプロジェクトが示したい「AWS 上での実運用に近いデプロイ設計」を保てる。Lambda へ寄せると待機コストは下げやすいが、アプリケーションとデプロイ方式の形が大きく変わり、ポートフォリオとして示したい ALB / ECS / CodeDeploy / RDS の構成価値が薄くなる。

EC2 は制御性が高いが、少人数・dev 中心・通常 destroy 済みの環境では、host 管理を増やすより、Fargate に任せてアプリケーション、Terraform、Blue/Green デプロイ、IAM / network boundary の設計に集中する方が適している。

起動中の Fargate / ALB / NAT Gateway / RDS コストは残るが、これは [0008](./0008-on-demand-startup-and-routine-destroy-operation.md) のオンデマンド起動 / 通常 destroy 運用で抑える。従って、Fargate 採用は「常時最安」を狙う判断ではなく、実運用に近い構成再現性、デプロイ実証、運用負荷、短時間利用時のコストのバランスを取る判断である。

## 影響

- API runtime は ECS Fargate service / task definition が正となり、NestJS API は ECR image として deploy される
- ECS task は public IP を持たず、app private subnet で動作する。外部からは CloudFront / ALB 経由で到達し、RDS ingress は ECS security group からの通信に限定する
- CodeDeploy Blue/Green / Canary は ECS service と ALB target group を前提にするため、deployment module と ECS module の結合が残る
- dev 環境の最小 task size は 0.25 vCPU / 0.5 GB であり、負荷増加時は `desired_task_count`、CPU / memory、Auto Scaling の導入を再検討する
- 起動中は Fargate 単体だけでなく ALB / NAT Gateway / RDS など周辺リソースのコストも発生する。通常 destroy 済みの運用を外す場合は、コスト・可用性・セキュリティをあわせて再評価する
- Lambda へ移行する場合は、NestJS / GraphQL の実行方式、RDS 接続、deployment pipeline、observability を別設計として見直す必要がある
- ECS on EC2 へ移行する場合は、capacity provider、AMI / patch、host security、instance lifecycle、Auto Scaling Group の運用設計が追加で必要になる

## 関連

- [Issue #303](https://github.com/kmryst/terraform-hannibal/issues/303)
- [docs/architecture/terraform-modules.md](../architecture/terraform-modules.md) - Terraform module 構成と ECS Fargate 実装状況
- [docs/architecture/system-design.md](../architecture/system-design.md) - 3 層アーキテクチャ、スケーラビリティ、コスト最適化
- [docs/deployment/codedeploy-blue-green.md](../deployment/codedeploy-blue-green.md) - ECS CodeDeploy Blue/Green / Canary
- [docs/security/threat-model.md](../security/threat-model.md) - CloudFront / ALB / ECS / RDS の信頼境界と残存リスク
- [terraform/environments/dev/main.tf](../../terraform/environments/dev/main.tf) - dev 環境の ECS module 統合
- [terraform/modules/compute/ecs/main.tf](../../terraform/modules/compute/ecs/main.tf) - ECS Fargate service / task definition
- [0008](./0008-on-demand-startup-and-routine-destroy-operation.md) - オンデマンド起動 / 通常 destroy 運用
