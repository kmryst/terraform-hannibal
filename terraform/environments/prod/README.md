# terraform/environments/prod — 本番環境（未作成）

このディレクトリは、将来 prod 環境を Terraform で構築するためのスケルトンです。  
**現在 AWS リソースはデプロイされていません。**

## セットアップ手順

1. `dev/` 以下の `.tf` ファイルをこのディレクトリにコピーする

   ```bash
   cp ../dev/*.tf .
   ```

2. `backend.tf` を `backend.tf.example` を参考に作成し、`key` を prod 向けに変更する

   ```bash
   cp backend.tf.example backend.tf
   ```

3. `terraform.tfvars.example` を参考に `terraform.tfvars` を作成し、prod の値に書き換える

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

4. 変数の調整（最低限必要なもの）:

   - `environment = "prod"`
   - `domain_name`（prod ドメインまたはサブドメイン）
   - `hosted_zone_id`
   - `acm_certificate_arn_us_east_1`（us-east-1 の ACM ARN）
   - `db_instance_class`（prod は `db.t3.small` 以上推奨）
   - `desired_task_count`（prod は `2` 以上推奨）

5. 初期化とプラン確認

   ```bash
   terraform init
   terraform plan
   ```

6. 問題なければ apply

   ```bash
   terraform apply
   ```

詳細は [`docs/terraform-environments.md`](../../../docs/terraform-environments.md) を参照。
