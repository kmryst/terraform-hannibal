# 0007. 未使用の Access Analyzer / IAM read 権限を CICD Role から削除する

## ステータス

Accepted

## 日付

2026-05-31

## 決定内容

`HannibalCICDRole-Dev` の deploy policy から、未使用と確認した Access Analyzer 権限と IAM read-only check 権限を削除する。

削除対象は `AccessAnalyzer` Sid と、`iam:ListRoles` / `iam:ListPolicies` / `iam:SimulatePrincipalPolicy` を含む `IAMReadOnlyForCheck` Sid とする。

## 背景

`HannibalCICDRole-Dev` は main branch の deploy / destroy に使う Role であり、必要な権限に絞る必要がある。

Issue #293 では、environments/dev に Access Analyzer resource がなく、Terraform / deploy workflow からも Access Analyzer や IAM policy simulation を呼んでいないことを確認した。`Resource = "*"` の IAM read 権限を残す理由も薄い。

## 検討した選択肢

### 既存権限を残す

- 長所: 万一の将来利用で権限不足にならない
- 短所: deploy / destroy Role に未使用権限が残る

### Access Analyzer と IAM read-only check 権限を削除する

- 長所: CICD Role の権限を実際の使用範囲へ寄せられる
- 短所: 将来 Access Analyzer を Terraform 管理する場合は再追加が必要

### 別 Role へ移す

- 長所: 将来の分析用途を分離できる
- 短所: 現時点で呼び出し元がなく、管理対象だけが増える

## 採択理由

Access Analyzer と IAM policy simulation は現在の deploy / destroy 経路で使われていない。呼び出しコードも Terraform resource もない権限を main branch の自動化 Role に残すより、削除して必要になった時に再追加する方が最小権限の方針に合う。

この判断は、read 系 wildcard をすべて否定するものではない。Terraform provider refresh に必要な read 系 wildcard は用途とリスクを分けて扱い、未使用の分析・シミュレーション権限は削除する。

## 影響

- `HannibalCICDRole-Dev` の blast radius が小さくなる
- Access Analyzer を将来導入する場合は、専用 Issue で必要 resource と権限を再設計する
- docs は古い使用率数字ではなく、role 分離・write/exec 列挙・read 系 wildcard の意図・Permission Boundary を中心に説明する

## 関連

- [Issue #293](https://github.com/kmryst/terraform-hannibal/issues/293)
- [Security Design](../architecture/security-design.md#iam設計)
- [IAM Management](../operations/iam-management.md#最小権限化の設計方針)
