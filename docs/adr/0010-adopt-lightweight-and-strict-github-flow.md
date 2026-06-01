# 0010. 軽運用 / 厳密運用を分ける GitHub Flow モデルを採用する

## ステータス

Accepted

## 日付

2026-06-01

## 決定内容

`terraform-hannibal` では、Issue -> Branch -> PR -> Merge を基本としつつ、変更内容に応じて軽運用と厳密運用を分ける GitHub Flow モデルを採用する。

判断の核は次の 3 点である。

- すべての変更に共通の最低限のゲート（Issue リンク、必須ラベル、PR、required status checks）を課す
- 軽微な変更（軽運用）は Issue / PR 本文を最小限に保ち、速度を落とさない
- リスクの高い変更（厳密運用）はロールバック手順と影響範囲の明示を求め、確認を厚くする

`main` への direct push は branch protection で禁止し、PR と required status checks を通したうえで squash merge する。AI Agent / CLI / API からの起票や PR 作成も許容するが、Issue 作成前・ブランチ作成後の実装前・PR 作成前に人間が確認する計画提示を挟み、最終的な形式チェックは GitHub Actions に委ねる。

運用ルールの具体（必須ラベルの種類、`Closes / Fixes / Refs` の記法、軽運用 / 厳密運用に該当する変更の判定基準など）の正本は `CONTRIBUTING.md` とする。本 ADR はその具体を再掲せず、なぜこのモデルにしたかの判断理由を記録する履歴として扱う。設計意図、未採用案、将来の再検討条件は `docs/operations/github-flow-guardrails.md` に置く。

## 背景

このプロジェクトは少人数・dev 中心で運用するポートフォリオ用インフラである。一方で、Terraform、GitHub Actions、IAM / OIDC、deploy / destroy といった変更は、誤ると環境破壊や権限過多につながる。

すべての変更に重い承認や本文チェックを求めると、軽微な docs / CI 整理や AI Agent を使った小さな作業まで過剰に重くなる。逆に、Issue リンク、ラベル、CI、ロールバック条件を緩めすぎると、AI Agent / CLI / API からの作業で意図や影響範囲が追跡しづらくなる。

そのため、軽微な変更は軽く流せる余地を残しながら、Terraform / workflow / IAM / deploy / destroy / Security などの変更では厳密な確認が働くモデルが必要になった。

## 検討した選択肢

### 軽運用 / 厳密運用を分ける GitHub Flow（採択）

- 長所: 軽微な変更の速度を保ちつつ、リスクの高い変更ではロールバックや影響範囲の確認を厚くできる
- 長所: AI Agent / CLI / API の利用を前提にしても、Issue リンク、ラベル、CI、事前計画確認で品質を揃えやすい
- 短所: 軽運用か厳密運用かの判断を、ラベル、変更対象、変更内容から毎回確認する必要がある

### approval を常時必須にする

- 長所: すべての PR に人間レビューの明示的なゲートを置ける
- 短所: 少人数運用では重く、形式的な承認になりやすい

### CODEOWNERS を即導入する

- 長所: 領域ごとのレビュー責任を GitHub 上で明示できる
- 短所: 現状は責任分担の実益が薄く、少人数では運用コストが先に立つ

### dev Environment 承認を deploy / destroy に付ける

- 長所: deploy / destroy の実行前に追加の承認ゲートを置ける
- 短所: `deploy.yml` は手動実行であり、`destroy.yml` も `workflow_dispatch + DESTROY` 入力で強い確認を持っているため、dev 中心運用では二重承認になりやすい

### 全 PR で重い本文チェックを必須にする

- 長所: すべての PR 本文の粒度を揃えられる
- 短所: 軽微な docs / CI 修正にも過剰で、必要なゲートである Issue リンク、必須ラベル、CI より本文形式の負担が目立ちやすい

## 採択理由

少人数・dev 中心運用では、すべての変更を重い承認フローへ寄せるよりも、リスクに応じて確認の厚さを変える方が実効性が高い。

軽運用でも Issue、ラベル、PR、CI は必須にするため、最低限の追跡性と品質ゲートは残る。厳密運用では、ロールバック手順や影響範囲の明示を求めることで、Terraform、workflow、IAM、deploy / destroy、Security などの変更をより丁寧に扱える。

AI Agent を使う前提でも、Issue 作成前、実装前、PR 作成前に計画を提示して人間が確認する流れにすると、作業を完全停止させずに意図のズレを早い段階で直せる。最終的な形式チェックは GitHub Actions に寄せることで、人間は判断の質に集中しやすくなる。

## 影響

- 軽微な docs / chore / test 変更は、必要な構造を保ちながら軽く進められる
- Terraform、workflow、IAM / OIDC、deploy / destroy、Security などの変更は厳密運用として扱い、PR 本文に実効性のあるロールバック手順が必要になる
- Issue / PR の品質は、事前計画、人間確認、helper、GitHub Actions の組み合わせで担保する
- 将来、常時レビュー担当が複数名いる体制、本番相当の継続運用、領域オーナーの明確化が進んだ場合は、approval 必須化、CODEOWNERS、Environment 承認を再検討する

## 関連

- [Issue #301](https://github.com/kmryst/terraform-hannibal/issues/301)
- [Issue #297](https://github.com/kmryst/terraform-hannibal/issues/297)
- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Issue / Branch / Commit / PR / Label / 軽運用・厳密運用の正本
- [GitHub Flow Guardrails](../operations/github-flow-guardrails.md) - 設計意図、未採用案、将来の再検討条件
