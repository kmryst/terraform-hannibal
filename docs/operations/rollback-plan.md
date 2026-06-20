# Terraform Rollback Plan

この文書は Terraform 変更の戻し方をまとめる正本です。
通常の Terraform 操作手順は [terraform-runbook.md](./terraform-runbook.md) を参照します。
CodeDeploy の auto rollback やアプリケーションデプロイ障害は [runbook.md](./runbook.md) を参照します。

> **注意**: 以下のコマンド例は旧構成（`terraform/environments/dev`）に基づいています。state 分割後は、対象の root module ディレクトリ（`terraform/network`、`terraform/database`、`terraform/service`、`terraform/cdn`）に読み替えてください。

## 基本方針

- まず Git / Terraform 設定 / 実 AWS リソース / state のどこが壊れたかを切り分ける。
- 正常な Terraform apply の取り消しは、原則として Git revert した設定を再 apply して戻す。
- state 復元は「state 自体が壊れた、誤って上書きされた、実リソースと対応しなくなった」場合の最終手段として扱う。
- `terraform state rm`、S3 state object の復元、lockfile の手動削除は厳密運用として扱い、事前確認なしに実行しない。
- state lock は S3 lockfile を正とし、DynamoDB lock table `terraform-state-lock` は #189 まで移行期間用として併用する。force-unlock や state 操作を行う際は [terraform-runbook.md](./terraform-runbook.md) の前提セクションを参照する。
- state / plan / logs に secret が含まれる可能性があるため、値を貼り付けずに状態だけ共有する。

## 初動

1. どの Terraform root か確認する。
   - `terraform/foundation`
   - `terraform/environments/dev`
2. 直近の GitHub Actions run、手動 Terraform 実行、対象 commit / PR を確認する。
3. lock が残っている場合は、実行中の Terraform がないことを確認する。
4. 現在の state object version を記録する。
5. `terraform plan` または `terraform plan -refresh-only` で現在の差分を確認する。

```bash
gh run list --workflow deploy.yml --limit 5
gh run list --workflow destroy.yml --limit 5
gh run list --workflow pr-check.yml --limit 5

STATE_BUCKET="nestjs-hannibal-3-terraform-state"
STATE_KEY="environments/dev/terraform.tfstate"

aws s3api list-object-versions \
  --bucket "$STATE_BUCKET" \
  --prefix "$STATE_KEY" \
  --max-items 10 \
  --output table
```

## apply 中断・失敗時

### 1. 実行中かどうか確認する

GitHub Actions やローカル Terraform がまだ動いている場合は待ちます。
途中で lock を解除すると、同時実行により state を壊す可能性があります。

```bash
gh run list --workflow deploy.yml --limit 5
gh run list --workflow destroy.yml --limit 5
ps aux | grep '[t]erraform'
```

### 2. lock が stale か確認する

Terraform のエラー出力に `Lock ID` が出ている場合は、実行中の操作がないことを確認してから force-unlock します。

```bash
terraform -chdir=terraform/environments/dev force-unlock <LOCK_ID>
```

foundation の場合:

```bash
terraform -chdir=terraform/foundation force-unlock <LOCK_ID>
```

### 3. plan で整合を確認する

apply 失敗後は、成功した resource と失敗した resource が混在することがあります。
まず refresh ありの plan で Terraform が現状をどう見ているか確認します。

```bash
terraform -chdir=terraform/environments/dev plan \
  -refresh=true \
  -lock=true \
  -input=false \
  -detailed-exitcode \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

判断:

| 状況 | 対応 |
|---|---|
| state にあり、実リソースもある | 設定差分を確認し、必要なら再 apply |
| state にないが、実リソースがある | import を検討する |
| state にあるが、実リソースがない | 再作成するか、state 操作が必要かを Issue で判断する |
| provider / 権限不足で失敗 | IAM / provider / backend 設定を修正して再 plan |

## 誤変更時の revert

Terraform 設定が誤っていて apply 済みの場合、state を戻すのではなく、まず Git revert で設定を戻します。

```bash
git revert <commit-sha>
```

その後、対象 root で plan し、戻す差分を確認します。

```bash
terraform -chdir=terraform/environments/dev plan \
  -refresh=true \
  -lock=true \
  -input=false \
  -out=tfplan \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

dev application の通常 apply は `deploy.yml` を `main` から手動実行するルートを使います。
foundation の revert apply は `HannibalFoundationRole-Dev` で実行します。

```bash
terraform -chdir=terraform/foundation plan \
  -refresh=true \
  -lock=true \
  -input=false \
  -out=tfplan

terraform -chdir=terraform/foundation apply tfplan
```

## state 復元

state 復元は、S3 versioning により過去 version を current version としてコピーする操作です。
これは AWS リソースそのものを戻す操作ではありません。
通常の誤変更 rollback には使わず、state が壊れた場合だけ検討します。

### 1. 対象 state key を決める

| 対象 | State key |
|---|---|
| foundation | `foundation/terraform.tfstate` |
| dev application | `environments/dev/terraform.tfstate` |
| prod skeleton | `environments/prod/terraform.tfstate` |

### 2. version 一覧を確認する

```bash
STATE_BUCKET="nestjs-hannibal-3-terraform-state"
STATE_KEY="environments/dev/terraform.tfstate"

aws s3api list-object-versions \
  --bucket "$STATE_BUCKET" \
  --prefix "$STATE_KEY" \
  --output table
```

復元候補の `VersionId` と `LastModified` を確認します。
直近の current version も戻し先として記録しておきます。

### 3. 復元候補をローカルに取得して確認する

```bash
VERSION_ID="<restore-candidate-version-id>"

aws s3api get-object \
  --bucket "$STATE_BUCKET" \
  --key "$STATE_KEY" \
  --version-id "$VERSION_ID" \
  state-restore-candidate.tfstate

terraform show state-restore-candidate.tfstate
```

state には機密情報が含まれる可能性があります。
`terraform show` の出力を共有する場合は secret / credential 値を貼り付けません。

### 4. 過去 version を current version として復元する

並行 Terraform 実行がなく、lock が残っていないことを確認してから実行します。
この操作は古い version を削除せず、過去 version の内容を新しい current version としてコピーします。

```bash
aws s3api copy-object \
  --bucket "$STATE_BUCKET" \
  --copy-source "${STATE_BUCKET}/${STATE_KEY}?versionId=${VERSION_ID}" \
  --key "$STATE_KEY"
```

### 5. 復元後の確認

```bash
terraform -chdir=terraform/environments/dev init -reconfigure -input=false

terraform -chdir=terraform/environments/dev plan \
  -refresh=true \
  -lock=true \
  -input=false \
  -detailed-exitcode \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

foundation の場合は `terraform/foundation` で同じ確認を行います。

```bash
terraform -chdir=terraform/foundation init -reconfigure -input=false
terraform -chdir=terraform/foundation plan -refresh=true -lock=true -input=false -detailed-exitcode
```

## module revert

module の変更を戻す場合も、state を直接触らず Git revert から始めます。

1. 変更 commit を特定する。
2. `git revert <commit-sha>` で module コードを戻す。
3. 影響 module の target plan で差分を切り分ける。
4. target なしの full plan で最終差分を確認する。
5. 通常の PR / deploy ルートで戻す。

```bash
git revert <commit-sha>

terraform -chdir=terraform/environments/dev plan \
  -target=module.rds \
  -refresh=true \
  -lock=true \
  -input=false \
  -var="client_url_for_cors=https://hamilcar-hannibal.click" \
  -var="environment=dev" \
  -var="deployment_type=canary" \
  -var="enable_cloudfront=true" \
  -var="ecr_repository_url=${ECR_REPOSITORY_URL}" \
  -var="alb_certificate_arn=${ALB_CERTIFICATE_ARN}" \
  -var="acm_certificate_arn_us_east_1=${ACM_CERTIFICATE_ARN_US_EAST_1}" \
  -var="hosted_zone_id=${HOSTED_ZONE_ID}"
```

`-target` は切り分け用です。
target plan の結果だけで apply せず、最後に target なしの plan を確認します。

## 復旧後チェック

- 対象 Issue / PR に、発生時刻、原因、対応、残存リスクを記録した。
- `terraform plan` または `plan -refresh-only` で state と実リソースの整合を確認した。
- S3 state object の current version を確認した。
- lockfile が残っていないことを確認した。
- 必要なら [aws-resources.md](./aws-resources.md) と [iam-management.md](./iam-management.md) の記述を更新した。
