# 0003. Terraform state locking は S3 lockfile を正とする

## ステータス

Accepted

## 日付

2026-05-31

## 決定内容

Terraform の S3 backend では `use_lockfile = true` による S3 lockfile 方式を正とする。

DynamoDB state locking は移行期間中のみ併用し、安定確認後に `dynamodb_table`、DynamoDB lock 用 IAM 権限、関連 docs を削除する。

## 背景

S3 backend の DynamoDB-based locking は deprecated になっている。Terraform minor version の更新で運用負債になる前に、S3 lockfile 方式へ移行する必要がある。

一方で、Terraform state locking は apply / plan / deploy / destroy の基盤であり、一度に DynamoDB locking を削除するとロールバックや切り分けが難しくなる。

## 検討した選択肢

### DynamoDB locking を維持する

- 長所: 既存運用を変えずに済む
- 短所: deprecated な設定を残すことになり、将来の Terraform 更新リスクが残る

### S3 lockfile へ一括移行し、同時に DynamoDB を削除する

- 長所: 最終状態へすぐ到達できる
- 短所: lock 取得失敗や CI / deploy 影響が出た時に原因を切り分けにくい

### S3 lockfile を有効化し、安定後に DynamoDB を削除する

- 長所: 移行リスクを段階的に抑えられる
- 短所: 移行期間中は backend 設定と IAM 権限が二重になる

## 採択理由

state locking はインフラ変更の安全性に直結するため、二段階移行が妥当である。

まず `use_lockfile = true` を導入し、`.tflock` の作成・削除、`terraform init -reconfigure`、real plan、deploy / destroy への影響を確認する。その後、安定期間を経て DynamoDB locking を削除することで、deprecated 対応と運用安全性を両立できる。

## 影響

- 現在の正は S3 lockfile 方式
- DynamoDB lock table は移行期間中のみ残す
- DynamoDB 削除は #189 で扱う
- PR plan Role は `terraform plan -lock=false` 前提のため、S3 lockfile の write/delete 権限を持たない

## 関連

- [Issue #183](https://github.com/kmryst/terraform-hannibal/issues/183)
- [Issue #189](https://github.com/kmryst/terraform-hannibal/issues/189)
- [terraform/foundation/backend.tf](../../terraform/foundation/backend.tf)
- [terraform/environments/dev/backend.tf](../../terraform/environments/dev/backend.tf)
- [terraform/foundation/dynamodb.tf](../../terraform/foundation/dynamodb.tf)
