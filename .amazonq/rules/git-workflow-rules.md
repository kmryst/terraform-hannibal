# Git Workflow Rules

## 基本原則
- **Gitコマンドは必ず3つのステップに分けて実行する**
- 一括実行（`git add . && git commit -m "" && git push`）は禁止
- 各ステップで結果を確認してから次に進む

## 必須実行順序

### 1. ステージング
```bash
git add .
```

### 2. コミット
```bash
git commit -m "コミットメッセージ"
```

### 3. プッシュ
```bash
git push origin <ブランチ名>
```

## コミットメッセージ規則
- **コメントは短く簡潔に**
- **feat**: 新機能追加
- **fix**: バグ修正
- **docs**: ドキュメント更新
- **refactor**: リファクタリング
- **style**: コードスタイル修正
- **test**: テスト追加・修正

## 例
```bash
git add .
git commit -m "feat: 監視スクリプト統合"
git push origin feature/automation
```

## 禁止事項
- ❌ `git add . && git commit -m "" && git push`
- ❌ ワンライナーでの一括実行
- ❌ ステップをスキップした実行

## 理由
- 各ステップでエラー確認が可能
- コミット前にステージング内容を確認できる
- プッシュ前にコミット内容を確認できる
- トラブル時の原因特定が容易