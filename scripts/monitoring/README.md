# Monitoring Scripts

## Blue/Green Deployment Monitor

### blue-green-monitor.ps1

ECS Blue/Green Deploymentの状況をリアルタイム監視するPowerShellスクリプト

#### 機能
- ECSサービスのデプロイメント状況
- Blue/Greenターゲットグループのヘルス状態
- ALBリスナールールの設定状況
- 実行中のECSタスク一覧

#### 使用方法
```powershell
# PowerShell実行
.\scripts\monitoring\blue-green-monitor.ps1

# 15秒間隔で自動更新
# Ctrl+Cで停止
```

#### 前提条件
- AWS CLI設定済み
- 適切なIAM権限（ECS、ELB読み取り権限）
- PowerShell 5.1以上

#### 監視対象リソース
- ECSクラスター: `nestjs-hannibal-3-cluster`
- ECSサービス: `nestjs-hannibal-3-api-service`
- ターゲットグループ: `nestjs-hannibal-3-blue-tg`, `nestjs-hannibal-3-green-tg`
- ALB: `nestjs-hannibal-3-alb`