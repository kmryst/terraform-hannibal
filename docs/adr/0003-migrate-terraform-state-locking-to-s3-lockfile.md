# 0003. Terraform state locking は S3 lockfile を正とする

## ステータス

Accepted

## 日付

2026-05-31

## 決定内容

Terraform の S3 backend では `use_lockfile = true` による S3 lockfile 方式を正とする。

DynamoDB state locking は使用せず、全 root module の backend と IAM 権限を S3 lockfile 単独運用に統一する。移行期間に使用した手動管理の DynamoDB table は、S3 lockfile の実動作確認後に削除した。

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

- 2026-05-31 時点: `use_lockfile = true` 有効 / DynamoDB lock table は併用継続 / DynamoDB 削除（#189）は未実施
- 2026-06-21 時点: state 分割（#397）で新設した network / database / service / cdn の 4 root module を `use_lockfile = true` 単独に移行（#408）。`dynamodb_table` を削除し S3 lockfile のみで運用
- 2026-06-21 動作確認: 全 4 root module で `terraform plan -lock=true` 実行中に `.tflock` の作成を確認、plan 終了後に削除を確認。DynamoDB なしで S3 lockfile が正常に機能している
- 2026-06-21 #189: foundation の `dynamodb_table` と全 Role / Permission Boundary の DynamoDB lock 権限を削除し、全 5 root module を S3 lockfile 単独構成へ統一
- 2026-06-21 #189 マージ前確認: Foundation Role で `terraform init -reconfigure` と lock あり real plan を実行し、`.tflock` の作成・終了後削除を確認。plan は IAM policy 6件の in-place 更新のみ（`0 to add, 6 to change, 0 to destroy`）
- 2026-06-21 #189 対照試験: Foundation Role に `dynamodb:*` の明示 Deny を付けた session で `terraform init -reconfigure` と lock あり real plan が成功し、DynamoDB 権限なしで S3 lockfile 単独運用が成立することを確認
- 2026-06-21 #189 IAM 反映: bootstrap 権限で IAM policy 6件を in-place 更新（`0 added, 6 changed, 0 destroyed`）。反映後に Foundation Role で lock あり real plan が `No changes` となり、Developer / CICD / Foundation Role の旧 DynamoDB lock 操作が `implicitDeny` であることを確認
- 2026-06-21 #189 table 撤去: 実行中 workflow と全 5 root module の `.tflock` がなく、旧 table の 6件がすべて state digest の `-md5` レコードであることを確認してから、手動管理の DynamoDB table `terraform-state-lock` を削除。削除後の `DescribeTable` は `ResourceNotFoundException`、Foundation Role の lock あり real plan は `No changes`
- 現在の正は全 5 root module の S3 lockfile 単独運用
- PR plan Role は `terraform plan -lock=false` 前提のため、S3 lockfile の write/delete 権限を持たない

## 関連

- [Issue #183](https://github.com/kmryst/terraform-hannibal/issues/183)
- [Issue #189](https://github.com/kmryst/terraform-hannibal/issues/189)
- [Issue #408](https://github.com/kmryst/terraform-hannibal/issues/408)
- [PR #413](https://github.com/kmryst/terraform-hannibal/pull/413)
- [terraform/foundation/backend.tf](../../terraform/foundation/backend.tf)
- [terraform/network/backend.tf](../../terraform/network/backend.tf)
- [terraform/database/backend.tf](../../terraform/database/backend.tf)
- [terraform/service/backend.tf](../../terraform/service/backend.tf)
- [terraform/cdn/backend.tf](../../terraform/cdn/backend.tf)
