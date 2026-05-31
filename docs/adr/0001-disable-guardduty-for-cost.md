# 0001. GuardDuty はコスト優先のため常時有効化しない

## ステータス

Accepted

## 日付

2026-05-31

## 決定内容

GuardDuty は Terraform で再有効化できる候補として残すが、現在の dev / ephemeral environment では常時有効化しない。

脅威検知は CloudTrail、Athena、CloudWatch、PR / 定期 Security Scan を中心に確認し、GuardDuty は本番相当・継続公開・外部利用増加の段階で再検討する。

## 背景

このプロジェクトは本番サービスではなく、必要時だけ起動して通常は destroy 済みで停止しておく on-demand / ephemeral environment である（[0008](./0008-on-demand-startup-and-routine-destroy-operation.md)）。

GuardDuty は有効な脅威検知サービスだが、停止運用で固定費を抑える方針とは相性が悪い。現在は CloudTrail を S3 に集約し、Athena で監査ログを分析できる構成を優先している。

## 検討した選択肢

### GuardDuty を常時有効化する

- 長所: AWS 側の脅威検知を継続的に利用できる
- 短所: 環境を停止していても追加コストが発生しやすい

### GuardDuty を完全に削除する

- 長所: 設定が単純になる
- 短所: 将来有効化する時の設計意図が失われる

### GuardDuty を無効化した設計候補として残す

- 長所: コストを抑えつつ、再検討条件と有効化手順を残せる
- 短所: 常時検知のカバレッジは得られない

## 採択理由

現時点では、常時公開ではない dev / ephemeral environment に対して GuardDuty の固定的な運用コストを払う優先度は低い。

一方で、GuardDuty が不要という判断ではない。CloudTrail / Athena / Security Scan で現在の運用に必要な監査性を確保し、継続公開や本番相当環境へ移行する段階で GuardDuty 有効化を再検討する方が、このプロジェクトのコスト設計に合う。

## 影響

- GuardDuty finding によるリアルタイム検知は得られない
- CloudTrail / Athena の監査ログ分析がより重要になる
- 本番相当環境、共有環境、継続公開へ移る場合は再検討が必要

## 関連

- 前提: [0008](./0008-on-demand-startup-and-routine-destroy-operation.md) — オンデマンド起動 / 通常 destroy 運用（本 ADR はこの運用前提に依存する）
- [Security Design](../architecture/security-design.md#guardduty設定-コスト最適化のため無効化中)
- [terraform/foundation/guardduty.tf](../../terraform/foundation/guardduty.tf)
