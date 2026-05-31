# 0008. オンデマンド起動 / 通常 destroy 運用を採用する

## ステータス

Accepted

## 日付

2026-06-01

## 決定内容

`terraform/environments/dev/` 配下のアプリ全体インフラは、通常は `terraform destroy` 済みで停止しておき、デモや動作確認で見せるときだけ `deploy.yml`（`deployment_mode: provisioning`）で起動する「オンデマンド起動 / 通常 destroy 運用」を採用する。

state backend・IAM / OIDC・CloudTrail / Athena・Route53・ACM などの永続リソースは destroy 後も残す（`docs/operations/aws-resources.md` の永続リソース一覧が正本）。

この運用は、コストを理由に引いている子 ADR（[0001](./0001-disable-guardduty-for-cost.md) / [0002](./0002-accept-waf-disabled-for-demo-environment.md) / [0004](./0004-keep-internet-facing-alb-with-cloudfront-origin-controls.md)）が共通して依存する**親の前提**として位置づける。

## 背景

このプロジェクトは本番サービスではなく、デモ / ショーケース用途の環境である。継続的にユーザートラフィックを受けるものではなく、稼働率は低く、必要なときだけ起動して確認する使い方が中心になる。一方で、ECS Fargate / RDS / ALB / CodeDeploy Blue-Green といった動的なインフラを、IaC で再現可能な形で構築・破棄できること自体に価値がある。

一方で、これらの一時リソースを常時起動しておくと、デモしていない時間帯にも継続的に課金が発生する。この用途では稼働率が低く、待機している時間がほとんどになる。

コスト系の設計判断（GuardDuty 無効化・WAF accepted risk・internet-facing ALB 維持）は、いずれも「通常は停止していて、必要時だけ起動する」という運用を理由に引いているが、その運用そのものを記録した ADR がなかった。そのため、コストを理由にした判断が連続する根拠を一箇所で追跡できるよう、本 ADR で親の前提として明文化する。

## 検討した選択肢

### 常時起動（24/7）

- 長所: いつでも即アクセスでき、本番に近い常時稼働の構成を示せる
- 短所: 構成スペックからの試算で月額 $30-50 程度（NAT Gateway・ALB・RDS・Fargate が主因）が継続的に発生する。停止運用の $5 以下と比べ、稼働率の低いポートフォリオには割高

  **注記: この常時起動運用は実際には行っておらず、上記コストは実測値ではなく構成スペックからの試算である。** 内訳の根拠は `docs/architecture/system-design.md` のコスト最適化セクションを参照。

### 完全削除（静的サイトのみ残す）

- 長所: 一時リソースを作らないため、待機コストをさらに切り詰められる
- 短所: ECS / RDS / Blue-Green デプロイなどの動的インフラを見せられず、IaC の再現性・運用設計というポートフォリオの主要な見せ場が失われる

### オンデマンド起動 / 通常 destroy（採択）

- 長所: 待機中は永続リソースのみの月額 $5 程度に抑えられ、見せるときだけ一時リソースのコストを払う。destroy と deploy を繰り返せること自体が IaC の冪等性・再現性の実証になる
- 短所: デモの前に起動（provisioning）の所要時間（目安15分）が必要で、常時即アクセスはできない

## 採択理由

待機時 $5 程度と起動時 $30-50 程度（試算）には大きな差があり、稼働率の低いポートフォリオ用途では常時起動のコストは割に合わない。

加えて、destroy 済み状態から `deploy.yml` で毎回再構築できることは、IaC が壊れず冪等に再現できることの実証になり、ポートフォリオとしての説明価値が高い。完全削除では動的インフラを示せないため、一時リソースは IaC として保持したうえで、通常は destroy しておく本運用が、コストと見せ場のバランスとして最も適している。

なお、これは「停止運用ありき」を新たに再決定するものではなく、既に行われている運用判断を遡及的に ADR として記録するものである。

## 影響

- `terraform/environments/dev/` は通常 destroy 済みが既定状態であり、デモには起動（provisioning、目安15分）の準備時間が必要になる
- 永続リソース（state backend・IAM / OIDC・CloudTrail / Athena・Route53・ACM など）は destroy 後も残り、待機中も月額 $5 程度が発生する
- 停止中はサービスが稼働しないため、リアルタイムの脅威検知・監視は動作しない。監査は CloudTrail / Athena の蓄積ログで担保する
- コスト系の子 ADR（0001 / 0002 / 0004）は本 ADR の運用前提に依存する。常時起動・継続公開・本番相当へ移行する場合は、本 ADR と各子 ADR をあわせて再検討する

## 関連

- [Issue #300](https://github.com/kmryst/terraform-hannibal/issues/300)
- [docs/operations/aws-resources.md](../operations/aws-resources.md) — 永続リソース / 一時リソースの運用前提（正本）
- [docs/operations/README.md](../operations/README.md#-日常運用タスク) — サービス起動 / 停止の手順
- [docs/architecture/system-design.md](../architecture/system-design.md#コスト最適化実装済み) — コスト内訳の試算根拠
- [0001](./0001-disable-guardduty-for-cost.md) — GuardDuty 無効化（本 ADR を前提とする子）
- [0002](./0002-accept-waf-disabled-for-demo-environment.md) — WAF accepted risk（本 ADR を前提とする子）
- [0004](./0004-keep-internet-facing-alb-with-cloudfront-origin-controls.md) — internet-facing ALB 維持（本 ADR を前提とする子）
