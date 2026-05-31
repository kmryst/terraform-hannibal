# 0002. WAF 無効化をデモ環境の accepted risk として扱う

## ステータス

Accepted

## 日付

2026-05-31

## 決定内容

CloudFront / ALB の WAF は現時点では有効化せず、ポートフォリオ / デモ環境における accepted risk として扱う。

Trivy Config の WAF finding は review signal として継続確認し、外部公開時間・アクセス量・攻撃的アクセスが増えた場合は CloudFront Web ACL を優先候補として再検討する。

## 背景

Trivy Config は WAF 無効化を検出する。WAF は外部公開面の防御として有効だが、このプロジェクトは通常停止運用で、必要時だけデモ環境を起動する。

また、DB は private subnet 上にあり、ALB への直アクセスも CloudFront managed prefix list と origin verify header によって制限している。

## 検討した選択肢

### CloudFront / ALB の WAF を常時有効化する

- 長所: 外部公開面の防御が増える
- 短所: 短時間デモ用途に対して固定費と運用対象が増える

### WAF finding を ignore して記録しない

- 長所: CI 上のノイズは減る
- 短所: 意図的なリスク受容か、見落としかが判別できなくなる

### WAF 無効化を accepted risk として記録する

- 長所: コスト理由と再検討条件を明示できる
- 短所: WAF による防御は得られない

## 採択理由

デモ環境は常時公開ではなく、通常は停止しているため、WAF の費用対効果は現時点では高くない。

ただし、WAF は不要という判断ではない。Trivy Config の finding は引き続き review signal として扱い、公開時間・アクセス量・攻撃面・本番相当性が変わった時点で再検討できるよう、accepted risk として記録する。

## 影響

- WAF ルールによる L7 防御は得られない
- CloudFront 経由制限、ALB listener rule、private subnet、Security Scan の維持が重要になる
- 継続公開へ移行する場合は CloudFront Web ACL の導入を優先的に検討する

## 関連

- [Security Design](../architecture/security-design.md#waf-無効化の-accepted-risk)
- [Quality Gates](../operations/quality-gates.md#waf-無効化の扱い)
