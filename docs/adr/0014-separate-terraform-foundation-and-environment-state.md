# 0014. Terraform foundation / environments のルートモジュールと state を分離する

## ステータス

Accepted

## 日付

2026-06-04

## 決定内容

Terraform は `terraform/foundation` と `terraform/environments/<env>` を別のルートモジュールとして管理し、S3 backend の state key も分離する。

- `terraform/foundation`: IAM / OIDC / Permission Boundary / CloudTrail / Athena / Budgets など、環境を作成・操作するための基盤リソースを扱う。state backend の S3 bucket は bootstrap 上の理由で手動管理とし、foundation は IAM で state と S3 lockfile へのアクセス権を管理する
- `terraform/environments/<env>`: ECS / ALB / RDS / S3 frontend / CodeDeploy など、アプリケーション環境のリソースを扱う

S3 bucket は共有してよいが、state key は `foundation/terraform.tfstate` と `environments/<env>/terraform.tfstate` に分ける。現在の実稼働環境は `dev` のみであり、将来の `staging` / `prod` は `terraform/environments/<env>` 配下に追加する。

## 背景

このプロジェクトでは、dev 環境を通常 destroy 済みにして必要な時だけ起動する運用を採用している。一方で、GitHub Actions OIDC、CICD Role、PR plan Role、Permission Boundary、CloudTrail / Athena / Budgets のような基盤リソースは、アプリケーション環境を destroy しても残す必要がある。state backend の S3 bucket は bootstrap 上の理由（Terraform 管理の state 保存先を同じ Terraform で作ると鶏と卵になる）で手動管理としており、foundation は IAM で state と S3 lockfile へのアクセス権を管理する。

アプリケーション環境と foundation を同じ Terraform state に入れると、dev の destroy や環境追加のたびに、IAM / OIDC / state backend などの永続基盤まで同じ apply 境界に入る。これは blast radius が大きく、権限設計やレビュー観点も混ざりやすい。

また、将来 `staging` / `prod` を追加する場合、環境ごとに変わるドメイン、証明書、RDS sizing、task count、CI/CD Role を分けつつ、foundation 側の IAM / OIDC / backend を共通の基盤として扱える構造が必要になる。

## 検討した選択肢

### すべてを単一ルートモジュール / 単一 state に入れる

- 長所: 初期構成が単純で、Terraform 実行箇所が 1 つで済む
- 短所: dev destroy と foundation 変更の境界が混ざり、IAM / OIDC / backend state まで誤って変更するリスクが上がる
- 短所: `staging` / `prod` 追加時に環境差分と基盤差分を分離しづらい

### 環境ごとに foundation も複製する

- 長所: `dev` / `staging` / `prod` が完全に独立した Terraform 実行単位になる
- 短所: OIDC provider、共通の Permission Boundary、監査・コスト管理リソースなどを環境ごとに重複管理しやすい
- 短所: 少人数・dev 中心運用では管理対象が増え、変更漏れや drift の確認コストが上がる

### foundation と environments を別ルートモジュール / 別 state に分離する

- 長所: 永続基盤と一時的なアプリケーション環境の lifecycle を分けられる
- 長所: IAM / OIDC / Permission Boundary 変更を厳密運用として扱いやすい
- 長所: `environments/<env>` の追加で将来の環境拡張に対応しやすい
- 短所: Terraform 実行単位が増え、Role や runbook で「どちらを apply するか」を明示する必要がある

### state backend 自体も Terraform 管理にする（bootstrap 用 root / 別 state を持つ）

- 長所: S3 state bucket と lock 設定も IaC で再現でき、初期構築手順の drift を減らせる
- 短所: bootstrap の state をどこに置くかが再帰し、local state か「同一 bucket + `prevent_destroy`」などの追加対策が必要になる
- 短所: 誤 destroy / state 破損時の復旧コストが最大級の backend を、Terraform 実行経路に乗せることになる
- 短所: 少人数・dev 中心運用では、bootstrap を IaC 化して得られる再現性の利点が薄い

## 採択理由

foundation と environments では、保持すべき期間、変更頻度、必要な権限、レビュー観点が異なる。

foundation は環境を作るための土台であり、日常の deploy / destroy から切り離して永続管理する必要がある。IAM / OIDC / Permission Boundary は誤変更時の影響が大きいため、`terraform/foundation` に閉じて厳密運用で扱う方が安全である。state backend の S3 bucket は Terraform 管理外だが、state と S3 lockfile へのアクセス権は foundation の IAM で制御しており、foundation の apply 境界に含まれる。

一方で、`terraform/environments/dev` はアプリケーション環境の再作成・破棄を前提にした実行単位であり、dev 固有のオンデマンド運用と相性がよい。state key を環境ごとに分けることで、dev の destroy や将来の prod apply が他の環境 state と競合しない。

同じ S3 bucket を共有しつつ key を分ける構成は、管理対象を増やしすぎずに state 境界を確保できる。state locking の方式自体は ADR 0003 の判断に従い、S3 lockfile を正とする。

state backend 自体を Terraform 管理にする案は、bootstrap state の置き場所が再帰し、復旧コストの高い backend を Terraform 実行経路に乗せる短所が、再現性の利点を上回るため採らない。state backend は `manual-resources.md` の手動管理リソースとして維持する。

## 影響

- `terraform/foundation` の state key は `foundation/terraform.tfstate` とする
- `terraform/environments/dev` の state key は `environments/dev/terraform.tfstate` とする
- 将来の環境は `terraform/environments/<env>` に追加し、state key は `environments/<env>/terraform.tfstate` とする
- foundation 変更は IAM / OIDC / Permission Boundary などを含むため、厳密運用で扱う
- dev 環境の deploy / destroy は environments 側の state に閉じ、foundation state を直接変更しない
- PR plan / deploy / destroy 用 Role の分離は ADR 0005 の判断に従う

## 関連

- [Issue #303](https://github.com/kmryst/terraform-hannibal/issues/303)
- [ADR 0003: Terraform state locking は S3 lockfile を正とする](./0003-migrate-terraform-state-locking-to-s3-lockfile.md)
- [ADR 0005: deploy/destroy 用 Role と PR plan 用 Role を分離する](./0005-separate-cicd-and-pr-plan-roles.md)
- [ADR 0008: オンデマンド起動 / 通常 destroy 運用を採用する](./0008-on-demand-startup-and-routine-destroy-operation.md)
- [Terraform 環境分離設計](../terraform-environments.md)
- [手動管理 AWS リソース一覧](../operations/manual-resources.md)
- [IAM権限管理](../operations/iam-management.md)
- [terraform/foundation/backend.tf](../../terraform/foundation/backend.tf)
- [terraform/environments/dev/backend.tf](../../terraform/environments/dev/backend.tf)
