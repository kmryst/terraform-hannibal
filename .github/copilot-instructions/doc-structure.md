## 📚 ドキュメント構造

コード変更時は関連ドキュメントも必ず更新：

```
docs/
├── architecture/          # システム設計書
│   ├── system-design.md   # 全体アーキテクチャ
│   ├── data-architecture.md
│   └── aws/              # AWS構成図（自動生成）
├── deployment/           # デプロイ手順
│   └── codedeploy-blue-green.md  # Blue/Green詳細
├── operations/           # 運用手順
│   └── README.md         # IAM管理・監視・分析
├── security/             # セキュリティ設計
│   └── iam-analysis/
├── setup/                # 環境構築
│   └── README.md
└── troubleshooting/      # トラブルシュート
    └── README.md         # 実装時の課題と解決方法
```

---
