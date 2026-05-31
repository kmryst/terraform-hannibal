# 0006. PR plan Role の read 系 wildcard を限定的に許容する

## ステータス

Accepted

## 日付

2026-05-31

## 決定内容

`HannibalPRPlanRole-Dev` では、Terraform provider の refresh に必要な read / list / describe / get 系について、限定的に prefix wildcard を許容する。

write / mutate 系権限は明示的に含めず、Permission Boundary でも read 系を上限として制限する。

## 背景

Terraform plan は refresh の過程で、provider version や既存リソース状態に応じて複数の read API を呼び出す。

特に S3 は `GetBucketCORS`、`GetBucketWebsite`、`GetAccelerateConfiguration`、object metadata 参照など、個別列挙にすると provider 更新のたびに不足権限が発生しやすい。実際の PR plan を安定運用するには、read-only の範囲で whack-a-mole を避ける必要がある。

## 検討した選択肢

### read API もすべて個別列挙する

- 長所: 形式上の最小権限に近づく
- 短所: Terraform provider の挙動変化で PR plan が頻繁に壊れる

### read / write を含む広い wildcard を許可する

- 長所: plan は壊れにくい
- 短所: PR 経路に過剰な変更権限を与える

### read 系 prefix wildcard のみ許容する

- 長所: plan の安定性と権限制限を両立できる
- 短所: read 可能なメタデータ範囲は広がる

## 採択理由

PR plan Role の目的は apply ではなく、レビュー補助として real state と既存 AWS リソースを読むことである。

read 系 wildcard は情報露出リスクを持つが、write / delete / pass role 権限とはリスクの質が異なる。PR plan Role は repository 内 PR に限定し、fork PR では skip し、state read も必要範囲へ制限する。さらに Permission Boundary で write 系混入を防ぐため、read 系 prefix wildcard は許容できる。

## 影響

- PR plan は Terraform provider の read API 変化に対して壊れにくくなる
- state や AWS resource metadata を読む Role であるため、信頼できる repository 内 PR だけで使う
- write 系権限、`iam:PassRole`、`secretsmanager:GetSecretValue`、S3 lockfile write/delete は引き続き禁止する

## 関連

- [PR Terraform Plan Role Design](../operations/pr-terraform-plan-role-design.md#terraform-read-permissions)
- [IAM Management](../operations/iam-management.md#最小権限化の設計方針)
- [terraform/foundation/iam.tf](../../terraform/foundation/iam.tf)
