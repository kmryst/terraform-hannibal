# terraform/foundation/guardduty.tf
# GuardDuty脅威検知（コスト削減のため無効化中）
# AWS Professional設計: セキュリティ監視基盤

# --- GuardDuty Detector ---
# 有効化する場合: コメントアウトを解除して terraform apply
# コスト: 約$3-5/月（イベント数により変動）

# resource "aws_guardduty_detector" "main" {
#   enable = true
#   
#   finding_publishing_frequency = "FIFTEEN_MINUTES"
#   
#   datasources {
#     s3_logs {
#       enable = true
#     }
#     kubernetes {
#       audit_logs {
#         enable = false
#       }
#     }
#     malware_protection {
#       scan_ec2_instance_with_findings {
#         ebs_volumes {
#           enable = false
#         }
#       }
#     }
#   }
#   
#   tags = {
#     Name        = "${var.project_name}-guardduty"
#     Environment = "all"
#     ManagedBy   = "terraform"
#   }
# }

# --- 実装後の管理方針 ---
# 1. コメントアウトを解除
# 2. terraform apply で有効化
# 3. 不要時は terraform destroy ではなく、再度コメントアウト
# 4. コードは再現性・ドキュメント用に保持

# --- 企業レベル設計原則 ---
# Netflix/Airbnb/Spotify標準パターン:
# - 基盤セキュリティ: GuardDuty常時監視
# - コスト最適化: 開発環境では無効化も選択肢
# - 監査性: CloudTrail + Athena分析と連携
