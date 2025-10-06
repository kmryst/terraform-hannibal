# --- Foundation Resources (基盤リソース) ---
# IAMロール・ポリシーは terraform/foundation/ で管理
# 永続化済み（手動管理・destroy対象外）

# --- Application Resources (アプリケーションリソース) ---

# Note: ECS service role removed - using standard ECS service linking
# Blue/Green deployments will be handled via external deployment tools (CodeDeploy, etc.)

# --- IAM Role for ECS Task ---
# ECSタスクがAWSのサービス（例：ECRからイメージのpullなど）にアクセスするためのIAMロールを作成
# このロールは、ECSタスクがAWSのサービスを利用する際の認証に使用されます
resource "aws_iam_role" "ecs_task_execution_role" {
  name                 = "${var.project_name}-ecs-task-execution-role"          # プロジェクト名をプレフィックスとして使用
  permissions_boundary = "arn:aws:iam::258632448142:policy/HannibalECSBoundary" # ECS専用Permission Boundary

  # このロールをECSタスクが引き受けることができるようにするポリシー
  # assume_role_policyは、どのAWSサービスがこのロールを引き受けることができるかを定義します
  assume_role_policy = jsonencode({ # assume 引き受ける ロールにポリシーをアタッチしている
    Version = "2012-10-17",         # IAMポリシーのバージョン
    Statement = [
      {
        Action = "sts:AssumeRole",
        # ECSタスクがIAMロールを使うとき、裏側でAWS STS（Security Token Service）が「一時的な認証情報」を発行し、そのロールの権限でAWSサービスにアクセスできるようにします
        Effect = "Allow",                     # 許可する
        Principal = {                         # このロールを引き受けることができる「主体」
          Service = "ecs-tasks.amazonaws.com" # ECSタスクサービスがこのロールを引き受けられる
        }
      }
    ]
  })
}

# aws_iam_role_policy_attachment IAMロールにポリシーをアタッチする
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name                               # 先ほど作成したロールの.name 属性
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" # AWSが提供するマネージドポリシー
}