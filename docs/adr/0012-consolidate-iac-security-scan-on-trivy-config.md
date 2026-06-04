# 0012. IaC security scan を Trivy Config に集約し tfsec を新規採用しない

## ステータス

Accepted

## 日付

2026-06-04

## 決定内容

`terraform-hannibal` の PR 品質ゲートでは、Terraform / Dockerfile などの IaC security scan を `trivy config` に寄せ、`tfsec` を新規の PR job / required status check として採用しない。

Terraform の基本整合性は `terraform fmt` / `terraform validate`、Terraform / AWS provider 向けの lint は `tflint`、secret 混入検出は `gitleaks` が担う。`trivy config` は IaC / Dockerfile の misconfiguration を横断的に確認する review signal として扱う。

この ADR は、`Trivy Config Scan` を blocking gate にするかどうかの判断ではない。既存 finding には accepted risk 候補や整理が必要な項目が含まれるため、`exit-code: 1` への変更や required status check 化は、finding の分類と ignore / accepted risk の記録を行った後に別 Issue で判断する。

## 背景

Issue #226 で `TFLint` / `Trivy Config Scan` / `Gitleaks Secret Scan` を PR check に追加し、Issue #228 で観察期間後に `TFLint` と `Gitleaks Secret Scan` を required status checks に追加した。`Trivy Config Scan` は HIGH / CRITICAL finding を表示するが、現時点では検出しても workflow を fail させない review signal として扱っている。

このプロジェクトの品質ゲートは、単に静的解析ツールを増やすことではなく、目的ごとに責務を分けて設計していることを示すためのものでもある。Terraform 専用の IaC security scanner として `tfsec` を追加すると、`trivy config` と検出領域が重なり、finding の解釈、ignore、accepted risk、CI job、version 管理の運用対象が増える。

一方で、このリポジトリの IaC / security scan は Terraform だけを対象にしない。PR では Dockerfile の設定ミスも見たい。定期 Security Scan でも Trivy を dependency / container scan に使っており、Aqua Security 系の scan を Trivy に寄せると、ツール説明と運用のまとまりを保ちやすい。

## 検討した選択肢

### Trivy Config に集約し tfsec は新規採用しない（採択）

- 長所: Terraform と Dockerfile など複数種類の設定ファイルを同じ scan 系統で確認できる
- 長所: PR check と定期 Security Scan の説明を Trivy 中心に揃えられ、ツール数・CI job・version 管理・ignore 運用を増やさずに済む
- 長所: `tfsec` と `trivy config` の重複 finding によるレビュー負荷や accepted risk の二重管理を避けられる
- 短所: Terraform 専用 scanner を併用する場合と比べると、特定 rule の差分を別途確認したい場面が残る

### Trivy Config に加えて tfsec も PR gate に追加する

- 長所: Terraform 専用 scanner の rule set を追加でき、片方の scanner だけでは見落とす項目を補える可能性がある
- 短所: IaC security という同じ目的の job が増え、finding の重複、severity 差分、ignore 記法、false positive / accepted risk の扱いを二重に管理する必要がある
- 短所: 既存の Trivy finding を blocking gate 化する前の棚卸しが終わっていないため、先に別 scanner を増やしても運用判断の問題は解決しない

### tfsec に寄せて Trivy Config を外す

- 長所: Terraform 専用の IaC security scan に集中できる
- 短所: Dockerfile など Terraform 以外の設定ミスを同じ PR gate で確認する設計から外れる
- 短所: 定期 Security Scan で Trivy を使っている流れと分かれ、品質ゲート全体の説明が散らばる

### Terraform 公式チェックと TFLint / Gitleaks のみにする

- 長所: PR check の toolchain が軽くなる
- 短所: WAF、KMS / CMK、Dockerfile root user など、Terraform 公式チェックや lint / secret scan だけでは拾いにくい misconfiguration の review signal が弱くなる

## 採択理由

このプロジェクトでは、IaC security scan の目的は Terraform だけの static analysis ではなく、Terraform / Dockerfile などの設定ミスを PR 上で早期に見つけることである。そのため、横断的に扱える `trivy config` に寄せる方が、品質ゲートの責務を説明しやすい。

また、現時点での主要課題は scanner の数を増やすことではなく、`Trivy Config Scan` が検出している finding を修正対象、accepted risk、ignore 対象に分類し、blocking gate 化できる状態へ近づけることである。`tfsec` を追加しても、この分類作業は減らない。むしろ同じカテゴリの finding が増え、レビュー時に何を直すべきかが曖昧になりやすい。

`terraform fmt` / `terraform validate`、`tflint`、`trivy config`、`gitleaks` の役割を分けることで、Terraform としての整合性、provider lint、IaC / Dockerfile misconfiguration、secret 混入をそれぞれ確認できる。ツール数を抑えながら目的別の品質ゲートを保つため、`tfsec` は新規採用しない。

## 影響

- `tfsec` 用の workflow、依存関係、required status check、ignore ファイルは追加しない
- IaC security の review signal は `Trivy Config Scan` を正とする
- `Trivy Config Scan` の `exit-code: 0` と review signal 扱いは維持する
- `Trivy Config Scan` を blocking gate にする場合は、既存 finding の分類、accepted risk / ignore 理由の記録、`exit-code: 1` 化の影響確認を別 Issue で扱う
- Terraform 専用 rule が必要になった場合は、まず Trivy Config で表現できるか、既存 TFLint / Terraform validation / policy で補えるかを確認し、それでも不足する場合に追加 scanner の採用を再検討する

## 関連

- [Issue #303](https://github.com/kmryst/terraform-hannibal/issues/303)
- [Issue #226](https://github.com/kmryst/terraform-hannibal/issues/226)
- [Issue #228](https://github.com/kmryst/terraform-hannibal/issues/228)
- [Quality Gates](../operations/quality-gates.md) - PR 品質ゲートと `tfsec` を新規採用しない理由
- [GitHub Flow Guardrails](../operations/github-flow-guardrails.md) - PR 品質ゲート required 化方針
- [Security Design](../architecture/security-design.md) - security scan の全体像
- [0002](./0002-accept-waf-disabled-for-ephemeral-environment.md) - WAF 無効化を Trivy Config finding の accepted risk として扱う判断
- [0010](./0010-adopt-lightweight-and-strict-github-flow.md) - 軽運用 / 厳密運用と品質ゲートの運用モデル
