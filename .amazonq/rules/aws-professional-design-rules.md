# AWS Professional Design Rules

## 基本原則
- **以下の優先順位に基づいてAWS Certified Professional/Specialtyレベルの設計を提案する**
- 段階的アプローチではなく、最初から企業レベルの設計を提示する
- 学習目的でも、プロダクション品質の設計を基準とする
- 提案する設計の企業レベル品質を常に強調する

## 参考資料の優先順位

### 最優先（Tier 1）- 絶対的基準
1. Well-Architected Framework
2. AWS公式ドキュメント（サービス別）
3. AWS公式ベストプラクティスガイド

### 高優先（Tier 2）- 公式権威
4. AWS Architecture Center
5. AWS Prescriptive Guidance
6. AWS公式ホワイトペーパー
7. AWS Certified試験ガイド

### 中優先（Tier 3）- 公式実例
8. re:Invent公式セッション
9. AWS公式ブログ
10. AWS公式ケーススタディ
11. AWS re:Post（公式コミュニティ）

### 補完（Tier 4）- 実装参考
12. 企業レベル参考例（Netflix、Capital One等）
    - Netflix: 環境別ユーザー + ロール組み合わせ
    - Slack: GitOps + IAM Policy as Code
    - Twitch: Blue/Green IAM Deployment
    - Pinterest: Immutable Infrastructure + 権限テンプレート化
    - Airbnb: 段階的権限管理
    - Capital One: PermissionBoundary + Service Control Policy組み合わせ
    - Goldman Sachs: Multi-Account + Cross-Account Role Chain
    - JPMorgan Chase: 時限付きアクセス + Just-In-Time権限昇格
    - Spotify: チーム別 + 環境別分離
    - Uber: Service-Linked Role + 自動権限検出
    - Lyft: CloudFormation StackSets + 組織単位権限管理
    - Dropbox: AWS Organizations + 集中ログ管理
13. AWS Solutions Library
14. HashiCorp Learn（Terraform）
15. Stack Overflow（実装例）

### 参考程度（Tier 5）- 個人経験
16. GitHub Issues/Discussions
17. 業界標準フレームワーク（NIST等）
18. 技術ブログ（Qiita、Medium等）

## 設計原則

### 1. 基盤とアプリケーションの分離
- IAMユーザー、基本ロール: 永続化（手動管理）
- アプリケーションリソース: Terraform管理
- 基盤リソースはdestroy対象外

### 2. 環境分離
- 理想: 複数AWSアカウント分離
- 現実的: 環境別ユーザー + ロール分離
- 権限の環境変数切り替えは禁止（アンチパターン）

### 3. 最小権限原則
- 各環境に適切な権限レベル
- 開発環境でも必要以上の権限は与えない
- 段階的権限検証の仕組みを含める

### 4. 監査性とトレーサビリティ
- 全操作をCloudTrailで追跡可能
- 環境別・機能別の責任分離
- AssumeRoleによる権限使用履歴

### 5. Infrastructure as Code
- 手動作業の最小化
- 再現可能な設計
- バージョン管理による変更追跡

## 禁止パターン
- 単一ユーザーでの全環境管理
- 環境変数による権限切り替え
- 基盤リソースのTerraform管理（destroy対象）
- 権限の段階的拡張アプローチ

## 推奨実装順序
1. 基盤リソース永続化
2. 環境別権限設計
3. 監査・ログ設定
4. 自動化・CI/CD設定

## 回答フォーマット
- 企業レベルの品質であることを強調
- Netflix、Airbnb、Spotifyなどの企業事例を積極的に参照
- アンチパターンを明確に指摘