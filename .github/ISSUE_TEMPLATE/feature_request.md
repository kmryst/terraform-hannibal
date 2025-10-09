---
name: Feature Request (CLI)
about: 新機能/改善の要望チケット（CLI 用 Markdown テンプレート）
title: '[{type}] 短い要約（例: README.mdにGitHub運用セクション追加）' # {type} は手入力
labels: ['type:feature', 'area:infra', 'risk:low', 'cost:none']
assignees: []
---

### 種別（type）

上から1つ選び、同じ語をタイトルの {type} に転記してください。

- 選択肢:
  - Feature
  - Fix
  - Docs
  - Infra
  - Security
  - Chore

### 背景/目的（background）

なぜ必要か（1-3行）

- 例) README.mdにGitHub運用セクション追加

### 要件/スコープ（scope）

何を変えるか（箇条書き）

- 例) README.mdの最後にGitHub運用セクション追加

### 受け入れ条件（acceptance）

- [ ] テスト通過
- [ ] ドキュメント更新
- [ ] 監視/アラート更新
- [ ] セキュリティ/ポリシー確認

### ダウンタイム（downtime）

- 選択肢:
  - なし
  - あり

### ダウンタイム詳細（必要時）（downtime_detail）

- 例) メンテ窓 02:00-02:10

### リスクレベル（risk）

- 選択肢:
  - Low
  - Medium
  - High

### リスク根拠（Medium/High時）（risk_reason）

- 例) 本番ネットワーク経路変更

### コスト影響（cost）

- 選択肢:
  - なし
  - 小
  - 中
  - 大

### コスト根拠（必要時）（cost_basis）

- 例) NAT GW追加 0.062 USD/時

### 連携（links）

- [ ] ブランチ命名にIssue番号を含める
- [ ] PR本文にCloses記載

### 補足（notes）

既知の制約や代替案
