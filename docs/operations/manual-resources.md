# 手動管理 AWS リソース一覧

このファイルは Terraform 管理外で手動作成・手動管理している AWS リソースの一覧と、その設計判断を記録する。

## なぜこのドキュメントが必要か

`terraform destroy` を実行してもこれらのリソースは削除されない。
意図的に Terraform 管理から外しているリソースを明示することで、destroy/deploy 運用の影響範囲を正確に把握できる。

---

## 手動管理リソース一覧

### S3 バケット（Terraform state backend）

| 項目 | 値 |
|---|---|
| リソース | Amazon S3 |
| バケット名 | nestjs-hannibal-3-terraform-state |
| 用途 | Terraform state と S3 lockfile の保存先 |
| Terraform 参照方法 | backend 設定で参照。Terraform resource としては管理しない |

#### 手動管理の理由

state backend 本体を同じ Terraform state で管理すると、管理対象の state を保存する先も同じ Terraform で作るニワトリと卵の状態になる。削除すると state が失われ復旧困難になるため、手動管理の永続リソースとして扱う。

運用手順は [terraform-runbook.md](./terraform-runbook.md)、state 復元手順は [rollback-plan.md](./rollback-plan.md) を参照する。

DynamoDB-based locking は現行構成で使用しない。旧 `terraform-state-lock` table の移行・削除履歴は [ADR 0003](../adr/0003-migrate-terraform-state-locking-to-s3-lockfile.md) と Issue #189 を参照する。

---

### ACM 証明書（ALB 用、ap-northeast-1）

| 項目 | 値 |
|---|---|
| リソース | AWS Certificate Manager (ACM) |
| リージョン | ap-northeast-1 |
| 用途 | ALB の HTTPS リスナー |
| Terraform 参照方法 | `var.alb_certificate_arn`（GitHub Variables: `ALB_CERTIFICATE_ARN`） |

#### 手動管理の理由

ACM 証明書は DNS 検証が必要であり、初回発行時にドメイン所有者による手動操作が伴う。また、証明書は一度作成すれば長期間有効で、`terraform destroy` の影響を受けさせたくない永続リソースとして扱っている。

---

### ACM 証明書（CloudFront 用、us-east-1）

| 項目 | 値 |
|---|---|
| リソース | AWS Certificate Manager (ACM) |
| リージョン | us-east-1（CloudFront の要件） |
| 用途 | CloudFront ディストリビューションの HTTPS |
| Terraform 参照方法 | `var.acm_certificate_arn_us_east_1`（GitHub Variables: `ACM_CERTIFICATE_ARN_US_EAST_1`） |

#### 手動管理の理由

ALB 用と同様。CloudFront は us-east-1 の証明書しか使用できないため、別途発行が必要。destroy 対象外の永続リソース。

---

### ECR リポジトリ

| 項目 | 値 |
|---|---|
| リソース | Amazon ECR |
| リポジトリ名 | nestjs-hannibal-3 |
| 用途 | アプリケーションコンテナイメージの格納 |
| Terraform 参照方法 | `var.ecr_repository_url`（GitHub Variables: `ECR_REPOSITORY_URL`） |

#### 手動管理の理由

ECR にはデプロイ済みのイメージが蓄積される。`terraform destroy` でリポジトリごと削除されると過去イメージも失われ、ロールバックが不可能になる。dev 環境の destroy はアプリインフラ（ECS・RDS・ALB 等）のみを対象とし、イメージストアは永続させる設計とした。

---

### CloudFront Origin Access Control (OAC)

| 項目 | 値 |
|---|---|
| リソース | CloudFront Origin Access Control |
| 用途 | CloudFront から S3 への署名付きアクセス制御 |
| Terraform 参照方法 | `var.cloudfront_oac_id`（`data "aws_cloudfront_origin_access_control"` で参照） |

#### 手動管理の理由

OAC はリポジトリ横断で再利用できる設定であり、destroy のたびに再作成するリソースではない。CloudFront ディストリビューション本体は Terraform 管理だが、OAC は共有・永続リソースとして分離した。

---

### S3 バケット（フロントエンド静的ファイル用）

| 項目 | 値 |
|---|---|
| リソース | Amazon S3 |
| バケット名 | nestjs-hannibal-3-frontend |
| 用途 | フロントエンドビルド成果物の配信元 |
| Terraform 参照方法 | `data "aws_s3_bucket" "frontend_bucket"` で参照 |

#### 手動管理の理由

S3 バケット名はグローバルで一意であり、`terraform destroy` で削除されると名前の再取得が保証されない。フロントエンドコンテンツは destroy 後も保持したい永続データであるため、バケット自体は Terraform 管理外とした。destroy.yml ではオブジェクトのみ削除し、バケット本体は残す運用としている。

---

### Route53 ホストゾーン

| 項目 | 値 |
|---|---|
| リソース | Amazon Route 53 Hosted Zone |
| ドメイン | hamilcar-hannibal.click |
| 用途 | カスタムドメインの DNS 管理 |
| Terraform 参照方法 | `var.hosted_zone_id`（GitHub Variables: `HOSTED_ZONE_ID`）、`data "aws_route53_zone" "main"` で参照 |

#### 手動管理の理由

ホストゾーンはドメイン取得と紐づいており、destroy で削除すると NS レコードが失われドメイン解決が停止する。DNS は全環境共通の永続リソースであるため Terraform 管理外とした。

---

## Terraform 管理への移行候補

| リソース | 移行可否 | 理由 |
|---|---|---|
| ACM 証明書 | 条件付き可 | `aws_acm_certificate` + `aws_route53_record` で自動化できるが、destroy 対象外にする `lifecycle { prevent_destroy = true }` が必要 |
| ECR リポジトリ | 条件付き可 | `lifecycle { prevent_destroy = true }` を設定すれば管理可能。ただし現状の手動管理で問題は生じていない |
| CloudFront OAC | 可 | `aws_cloudfront_origin_access_control` で管理可能。優先度低 |
| S3 バケット | 条件付き可 | `prevent_destroy = true` で管理可能。現状の手動管理で問題なし |
| Route53 ホストゾーン | 条件付き可 | `prevent_destroy = true` が必須。destroy 運用の複雑度が上がるため現状維持を推奨 |

---

## 新しいリソースを追加する際の手順

1. 手動で AWS リソースを作成する
2. このファイルに以下を追記する
   - リソース種別・用途・Terraform 参照方法
   - 手動管理にした理由
   - 将来的な Terraform 管理移行の可否
3. 必要に応じて GitHub Variables にリソース ID/ARN を登録する
4. Terraform の `variable` または `data` ソースで参照する
