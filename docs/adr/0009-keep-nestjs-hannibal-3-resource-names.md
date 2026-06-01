# 0009. 既存の AWS リソース名 nestjs-hannibal-3-* をリネームしない

## ステータス

Accepted

## 日付

2026-06-01

## 決定内容

S3 バケット・CloudTrail・CloudWatch アラーム・SNS topic などの既存 AWS リソース名（`nestjs-hannibal-3-*`）は、リポジトリ名 `terraform-hannibal` と一致しないままにする。リネームは行わない。

## 背景

このプロジェクトは当初 `NestJS Hannibal 3` という名称で開発されており、AWS リソースはその命名規則に基づいて作成された。その後リポジトリ名は `terraform-hannibal` に変わったが、既存の AWS リソース名はそのまま残っている。

不一致の対象リソースは以下の通り（正本は `docs/operations/aws-resources.md`）。

| リソース種別 | 名前 |
|---|---|
| S3（Terraform state） | `nestjs-hannibal-3-terraform-state` |
| S3（CloudTrail ログ） | `nestjs-hannibal-3-cloudtrail-logs` |
| S3（Athena 結果） | `nestjs-hannibal-3-athena-results` |
| CloudTrail trail | `nestjs-hannibal-3` |
| SNS topic | `nestjs-hannibal-3-security-alerts` |
| CloudWatch alarm | `nestjs-hannibal-3-cloudtrail-*`（4件） |
| リソースタグ | `Project = "nestjs-hannibal-3"` |

## 検討した選択肢

### リネームする

- 長所: リポジトリ名とリソース名の一致。AWS コンソール上の見た目が統一される
- 短所:
  - S3 バケットはリネーム不可。削除→再作成＋データ移行が必要
  - Terraform state バケットの名前変更は backend 設定変更と `terraform init -migrate-state` を伴い、失敗時に state を失うリスクがある（risk:high）
  - CloudTrail trail・CloudWatch alarm・SNS topic も Terraform での再作成が必要
  - 得られる価値はリポジトリ名との見た目の一致（cosmetic）のみ

### 現状維持（採択）

- 長所: 既存リソースへの変更ゼロ。state 喪失・監査ログ断絶のリスクを回避できる
- 短所: リポジトリ名 `terraform-hannibal` と AWS リソース名 `nestjs-hannibal-3-*` の不一致が残る

## 採択理由

リネームによって得られる価値は cosmetic な一致のみであり、state バケット移行の risk:high に見合わない。

S3 バケットはリネームができない仕様であり、削除・再作成には CloudTrail ログや Athena 結果などの永続データの移行が必要になる。特に Terraform state バケットの名前変更は移行手順の誤りで state を喪失するリスクがあり、ポートフォリオとして致命的な問題となりうる。

技術的な設計・運用の品質を示すのがこのプロジェクトの目的であり、AWS コンソール上のリソース名の統一はその評価に影響しない。リネームは行わず、本 ADR で「意図して維持している不一致」として明示することで十分と判断する。

## 影響

- AWS コンソール・CloudTrail・CloudWatch 上のリソース名は `nestjs-hannibal-3-*` のまま継続する
- Terraform コード内のリソース名・タグ・backend 設定も変更しない
- この不一致は本 ADR によって意図した状態として記録される。将来、リソースを再作成する機会（大規模リファクタ・環境移行等）があれば、その時点で命名を統一することを検討する

## 関連

- [Issue #315](https://github.com/kmryst/terraform-hannibal/issues/315)
- [docs/operations/aws-resources.md](../operations/aws-resources.md) — 永続リソース一覧（正本）
