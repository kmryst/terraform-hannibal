# 0004. ALB は internet-facing のまま CloudFront 経由制限を追加する

## ステータス

Accepted

## 日付

2026-05-31

## 決定内容

ALB は `internal = true` に変更せず、internet-facing のまま維持する。

代わりに、Security Group を CloudFront origin-facing managed prefix list に限定し、CloudFront origin custom header と ALB listener rule によって CloudFront 経由の API origin 通信だけを forward する。

## 背景

CloudFront の API origin は `api.hamilcar-hannibal.click` を参照し、その DNS は Route53 alias で ALB に向いている。

この状態で ALB を単純に internal 化すると、現在の CloudFront custom origin から到達できなくなる可能性がある。CloudFront 経由の公開を維持しながら直アクセスを減らすには、public ALB を残しつつ ingress と listener で制限する必要がある。

## 検討した選択肢

### ALB を internal 化する

- 長所: public ALB finding を根本的に解消できる
- 短所: 現在の CloudFront custom origin 構成では到達性に影響する可能性が高い

### ALB を internet-facing のまま何も制限しない

- 長所: 構成変更が不要
- 短所: CloudFront を迂回した直アクセス面が広い

### internet-facing ALB を維持し、CloudFront 経由制限を追加する

- 長所: 既存経路を保ちつつ直アクセスを減らせる
- 短所: private origin 構成ほど閉じた設計ではない

## 採択理由

現在の構成では、CloudFront custom origin と public DNS を使う設計が前提になっている。internal ALB 化は CloudFront VPC origins などを含む private origin 構成として別設計にする方が安全である。

そのため、現段階では internet-facing ALB を維持し、CloudFront managed prefix list と origin verify header による二段制限を採用する。これは既存デモ環境の到達性を壊さず、直アクセス面を実用的に狭める判断である。

## 影響

- ALB は引き続き public resource として存在する
- Security Group は CloudFront origin-facing address からの ALB listener range のみ許可する
- listener rule は `X-Hannibal-Origin-Verify` が一致する場合のみ target group へ forward する
- internal ALB 化は CloudFront VPC origins を含む別設計として扱う

## 関連

- [Issue #232](https://github.com/kmryst/terraform-hannibal/issues/232)
- [Security Design](../architecture/security-design.md#public-alb-直アクセス制限)
- [Quality Gates](../operations/quality-gates.md#public-alb-直アクセス制限の扱い)
- [terraform/modules/security/security-groups/main.tf](../../terraform/modules/security/security-groups/main.tf)
