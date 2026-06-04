# 0013. 品質チェックを観察期間後に段階的 required 化する

## ステータス

Accepted

## 日付

2026-06-04

## 決定内容

`terraform-hannibal` の PR 品質チェックは、新しい check を追加した時点でただちに branch protection の required status check にしない。

まず PR workflow 上で自動実行し、必要に応じて job fail の有無を個別に決める。その後、false positive、実行時間、運用上の詰まり、検出時に PR を止める価値を観察し、安定して blocking gate として扱える check だけを段階的に required status check へ昇格する。

この方針に基づき、Issue #226 / PR #227 では `TFLint` / `Trivy Config Scan` / `Gitleaks Secret Scan` を PR check として追加したが、branch protection の required status checks にはすぐ含めなかった。Issue #228 では観察期間後の実行履歴を確認し、`TFLint` と `Gitleaks Secret Scan` を required status checks に追加した。一方で `Trivy Config Scan` は、既存 finding の分類や accepted risk / ignore の整理が必要なため、review signal として維持する。

この判断では `job fail` と `required status check` を分けて扱う。`TFLint` / `Gitleaks Secret Scan` は検出時に job を fail させるが、初期導入直後は required にはしない。`Trivy Config Scan` は HIGH / CRITICAL finding を表示するが、現時点では `exit-code: 0` として PR を止めない。

Terraform plan のように正常系で skip される job は、生の job を required status check にしない。将来 required 化する場合は、skip / success / fail を吸収する gate job を別に置き、その gate job を required 対象にする。

## 背景

このプロジェクトは少人数・dev 中心運用のポートフォリオ用インフラであり、軽い運用速度と、Terraform / CI / secret / security の品質保証を両立する必要がある。

PR に品質 check を増やすこと自体は有効だが、新規導入直後の check をすべて required にすると、false positive、既存設計上の accepted risk、実行時間のぶれ、外部ツールの一時障害によって、日常的な PR が過剰に止まる可能性がある。

一方で、secret 混入や Terraform / AWS provider の明確な lint エラーのように、検出時に merge を止める価値が高い check もある。すべてを review signal に留めると、品質ゲートとしての実効性が弱くなる。

そのため、PR 上で可視化する段階、job fail させる段階、branch protection の required status check として merge を止める段階を分け、実績を見て昇格する方針が必要になった。

## 検討した選択肢

### 観察期間後に段階的 required 化する（採択）

- 長所: 新規 check の安定性と finding の性質を確認してから merge blocking にできる
- 長所: `TFLint` / `Gitleaks` のように止める価値が高い check は、実績を確認したうえで required 化できる
- 長所: `Trivy Config Scan` や Terraform plan のように accepted risk / skip 条件が絡む check を、PR 運用ごと詰まらせずに扱える
- 短所: 初期導入から required 化判断までの間、branch protection では止まらない期間が残る

### 新規 check を追加した時点ですべて required にする

- 長所: 導入直後から品質ゲートとして強く効かせられる
- 短所: false positive や accepted risk の整理前に PR が止まり、軽微な作業までブロックされやすい
- 短所: `Trivy Config Scan` のように `exit-code: 0` の review signal を required にしても、finding を理由に止める gate にはならない

### 新規 check は required にせず review signal に留める

- 長所: PR が詰まりにくく、導入負荷が軽い
- 短所: secret 混入や明確な Terraform lint エラーでも、人間が見落とすと merge できてしまう
- 短所: branch protection による品質保証の説明力が弱くなる

### Terraform 公式 check だけを required にする

- 長所: `terraform fmt` / `terraform validate` は公式 CLI であり、挙動を説明しやすい
- 短所: provider 固有の lint、secret 混入、IaC / Dockerfile の misconfiguration を merge 前に十分補足できない
- 短所: DevOps ポートフォリオとして、目的別に品質ゲートを設計していることを示しにくい

## 採択理由

required status check は merge 可否に直結するため、追加する check の性質を確認してから branch protection に入れる方が、少人数運用では実効性が高い。

Issue #226 / PR #227 で追加した 3 job は、導入時点では責務が異なっていた。`TFLint` は Terraform / AWS provider の実務 lint、`Gitleaks Secret Scan` は secret 混入検出であり、検出時に PR を止める価値が高い。一方で `Trivy Config Scan` は WAF 無効化、KMS / CMK、Dockerfile root user など、既存設計の accepted risk 候補や整理が必要な finding を含んでいた。

Issue #228 では、#227 以降の `PR Check` workflow 実行履歴を確認し、対象 3 job が安定して完了していることを確認した。そのうえで、false positive や実行時間の問題が見られず、検出時に PR を止めるべき `TFLint` と `Gitleaks Secret Scan` だけを required status checks に追加した。

この段階的な判断により、品質ゲートを形だけ増やすのではなく、merge を止める check と review signal の役割を分けられる。branch protection の実設定は GitHub 側の状態であり Git 管理外のため、required 化した check は docs に記録し、問題が出た場合は docs revert と branch protection 更新の両方で戻す。

## 影響

- 新しい PR check を追加する場合は、初期状態で `job fail` させるか、required status check にするか、観察期間後に判断するかを明示する
- required status checks に追加する場合は、観察結果、false positive、実行時間、merge blocking にする価値、ロールバック手順を docs に残す
- `TFLint` と `Gitleaks Secret Scan` は required status checks として扱う
- `Trivy Config Scan` は、既存 finding の分類と accepted risk / ignore の記録が終わるまで review signal として扱う
- Terraform plan の required 化は、生の plan job ではなく gate job を required 対象にする方針で再検討する
- required status check の問題を戻す場合は、該当 docs の revert に加えて GitHub branch protection の `contexts` から対象 check を外す

## 関連

- [Issue #303](https://github.com/kmryst/terraform-hannibal/issues/303)
- [Issue #226](https://github.com/kmryst/terraform-hannibal/issues/226)
- [PR #227](https://github.com/kmryst/terraform-hannibal/pull/227)
- [Issue #228](https://github.com/kmryst/terraform-hannibal/issues/228)
- [Quality Gates](../operations/quality-gates.md) - PR 品質ゲートと required 化判断の正本
- [GitHub Flow Guardrails](../operations/github-flow-guardrails.md) - required status check と GitHub Flow の設計意図
- [0010](./0010-adopt-lightweight-and-strict-github-flow.md) - 軽運用 / 厳密運用と品質ゲートの運用モデル
- [0012](./0012-consolidate-iac-security-scan-on-trivy-config.md) - IaC security scan を Trivy Config に集約する判断
