# Architecture Decision Records

このディレクトリは、`terraform-hannibal` の重要な設計判断を ADR（Architecture Decision Record）として残す場所です。

既存の設計文書は現在の正本として維持し、ADR は「なぜその判断にしたか」を後から追跡するための履歴として扱います。

## 番号付け

- ファイル名は `NNNN-kebab-case-title.md` とする
- `NNNN` は 4 桁の連番とし、一度使った番号は再利用しない
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

## 一覧

| ADR | ステータス | 決定 |
|---|---|---|
| [0001](./0001-disable-guardduty-for-cost.md) | Accepted | GuardDuty はコスト優先のため常時有効化しない |
| [0002](./0002-accept-waf-disabled-for-demo-environment.md) | Accepted | WAF 無効化をデモ環境の accepted risk として扱う |
| [0003](./0003-migrate-terraform-state-locking-to-s3-lockfile.md) | Accepted | Terraform state locking は S3 lockfile を正とする |
| [0004](./0004-keep-internet-facing-alb-with-cloudfront-origin-controls.md) | Accepted | ALB は internet-facing のまま CloudFront 経由制限を追加する |
| [0005](./0005-separate-cicd-and-pr-plan-roles.md) | Accepted | deploy/destroy 用 Role と PR plan 用 Role を分離する |
| [0006](./0006-allow-read-prefix-wildcards-for-pr-plan-role.md) | Accepted | PR plan Role の read 系 wildcard を限定的に許容する |
| [0007](./0007-remove-unused-access-analyzer-permissions.md) | Accepted | 未使用の Access Analyzer / IAM read 権限を CICD Role から削除する |
