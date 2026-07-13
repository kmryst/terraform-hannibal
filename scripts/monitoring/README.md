# Enterprise Blue/Green Deployment Monitoring

## AWS Professional/Specialty Standard Implementation

### 統合監視スクリプト

**`deployment-monitor.ps1`** - Netflix/Airbnb/Spotify標準パターン

```powershell
# 現状確認
.\deployment-monitor.ps1 -Mode Status

# リアルタイム監視 (デプロイ中)
.\deployment-monitor.ps1 -Mode Monitor

# デプロイ後サマリー
.\deployment-monitor.ps1 -Mode Summary

# 詳細情報付き
.\deployment-monitor.ps1 -Mode Status -Detailed
```

### 監視項目

#### Status Mode

- CodeDeployアプリケーション状態
- ECSサービス状態  
- Blue/Green環境健全性
- トラフィック分散状況
- アプリケーションURL

#### Monitor Mode

- **15秒間隔**リアルタイム監視
- 環境健全性変化
- トラフィック切り替え監視
- ECSデプロイメント進行状況

#### Summary Mode

- デプロイ結果サマリー
- 最終的な環境状態
- アクティブ環境判定

### 企業レベル監視体系

```text
┌─ CloudWatch Dashboards (常時監視)
├─ CloudWatch Alarms (自動アラート)  
├─ deployment-monitor.ps1 (手動確認)
└─ AWS Console (詳細調査)
```

### 使用例

#### デプロイフロー

```powershell
# 1. デプロイ前状態確認
.\deployment-monitor.ps1 -Mode Status

# 2. デプロイ実行
.\scripts\deployment\deploy-codedeploy.ps1 -ImageTag "v1.2.3"

# 3. リアルタイム監視
.\deployment-monitor.ps1 -Mode Monitor

# 4. 結果確認
.\deployment-monitor.ps1 -Mode Summary
```

#### Blue/Green切り替え確認

```text
🔵 Blue Environment: 2 healthy
🟢 Green Environment: 0 healthy  
🎯 Active Environment: Blue

↓ (デプロイ中)

🔵 Blue Environment: 2 healthy
🟢 Green Environment: 2 healthy
🎯 Active Environment: Both (Deployment in progress)

↓ (切り替え完了)

🔵 Blue Environment: 0 healthy
🟢 Green Environment: 2 healthy
🎯 Active Environment: Green
```

### 旧スクリプト (非推奨)

以下は統合により不要:

- ~~`codedeploy-status.ps1`~~
- ~~`blue-green-status.ps1`~~  
- ~~`blue-green-monitor.ps1`~~

### CloudWatch統合 (推奨)

企業レベルでは以下も併用:

- **CloudWatch Dashboard**: ECS/ALB/CodeDeployメトリクス
- **CloudWatch Alarms**: 自動アラート・ロールバック
- **SNS通知**: Slack/Teams連携
