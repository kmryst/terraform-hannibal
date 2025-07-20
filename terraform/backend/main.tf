# terraform/backend/main.tf

# --- VPC Data Sources (既存のVPCとサブネットを使用する場合) ---
# dataソースは、「AWS上にすでに存在するVPCの情報を自動で取得する」ためのものです
# これにより、手動でVPC IDを指定する代わりに、Terraformが自動的にVPC情報を取得できます
# provider.tf でリージョン指定している
data "aws_vpc" "selected" { # AWSのVPC情報を取得して、selectedという名前でTerraform内から参照できるようにした
  # id = var.vpc_id # vpc_id を直接指定する場合
  default = true # デフォルトVPCを自動で探して、その情報（IDなど）を取得(なければエラー)
  # デフォルトVPCは、AWSアカウント作成時に自動的に作成されるVPCです
  # 通常、パブリックサブネットが含まれており、開発環境での使用に適しています
  # 各リージョンにはデフォルトVPCが1つ自動で用意されています（削除も可能）
  # それとは別に、1つのリージョン内で複数のVPCを自分で作成することも可能です
}

# これは「AWSにすでに存在するサブネットの情報のリストを、publicという名前で取得する」という宣言です
# ALBやECSなどは、そのリスト全部を指定して「複数AZ分散」を自動的にやってくれる
# 複数のAZにまたがることで、高可用性を確保できます
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"                   # 任意の文字列ではなく、AWSが認識できる属性名のみが有効です
    values = [data.aws_vpc.selected.id] # 先ほど取得したVPCのIDを使用
  }
  # 必要に応じてタグなどで絞り込み
  # tags = {
  #   Tier = "Public" # パブリックサブネットのみを取得する場合
  # }
}
# data.aws_subnets.public.ids で[ "subnet-xxxx", "subnet-yyyy", ... ] のようなリストが取得できます


# ⭐️ --- ECR Repository (手動作成済み) --- ⭐️
# ⭐️ 手動で作成済みのECRリポジトリを使用 ⭐️
# 理由: 権限エラー回避、CI/CD安定性向上、実行時間短縮
# ECR URI: variables.tfで定義済み

# ⭐️ --- ECR Lifecycle Policy (Terraform管理) --- ⭐️
# ⭐️ 古いイメージを自動削除するためのライフサイクルポリシー ⭐️
# Infrastructure as Code原則に従いTerraformで管理
resource "aws_ecr_lifecycle_policy" "nestjs_hannibal_3_policy" {
  repository = "nestjs-hannibal-3" # 直接リポジトリ名を指定

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# --- IAM User Permissions for hannibal user ---
# ※ 既存の手動アタッチ済みマネージドポリシーはAWSコンソールで一度detachし、Terraformで管理してください
# ※ 10個制限を超えないよう、不要なものはアタッチしない・カスタムポリシーに統合する

# dataソースではなく直接ユーザー名を指定（iam:GetUser権限不要）

# --- A. Core Policy（コア権限）---
resource "aws_iam_role" "hannibal_core_role" {
  name = "HannibalCoreRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::258632448142:user/hannibal"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "hannibal_core_policy" {
  name        = "HannibalCorePolicy"
  description = "Core permissions - ECS/ECR operations, CloudWatch Logs, IAM basic operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR認証トークン取得（アカウント単位で必要）
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        # ECRリポジトリ操作権限（リポジトリ単位）
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:GetLifecyclePolicy",
          "ecr:PutLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:ListTagsForResource",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "arn:aws:ecr:ap-northeast-1:258632448142:repository/nestjs-hannibal-3"
      },
      {
        # CloudWatch Logs権限 (ログ管理)
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
          "logs:DeleteLogGroup",
          "logs:GetLogEvents",    # ローカル確認専用: ログ内容を読み取る
          "logs:FilterLogEvents", # ローカル確認専用: ログをフィルタリング
          # GitHub Actions用の追加権限
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        # ECS権限 (Cluster, Service, Task Definition)
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:ListClusters",
          "ecs:DescribeServices",
          "ecs:ListServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DeleteCluster",
          "ecs:CreateCluster",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ]
        Resource = "*"
      },
      {
        # IAM権限 (Terraform用ロール・ポリシー管理)
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:GetUser",
          # GitHub Actions用の追加権限
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          # 追加: インラインポリシー操作用
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy"
        ]
        Resource = "*"
      },
      {
        # 他のロールへのAssumeRole権限（GitHub Actions用）
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          "arn:aws:iam::258632448142:role/HannibalInfrastructureRole",
          "arn:aws:iam::258632448142:role/HannibalMonitoringRole",
          "arn:aws:iam::258632448142:role/HannibalSecurityRole"
        ]
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/*"
        ]
      },
      {
        # EC2権限（VPC情報取得用）
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },

    ]
  })
}

resource "aws_iam_role_policy_attachment" "hannibal_core_policy_attachment" {
  role       = aws_iam_role.hannibal_core_role.name
  policy_arn = aws_iam_policy.hannibal_core_policy.arn
}

# --- B. Infrastructure Policy（インフラ権限）---
resource "aws_iam_role" "hannibal_infrastructure_role" {
  name = "HannibalInfrastructureRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::258632448142:user/hannibal",
            "arn:aws:iam::258632448142:role/HannibalCoreRole"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_policy" "hannibal_infrastructure_policy" {
  name        = "HannibalInfrastructurePolicy"
  description = "Infrastructure permissions - VPC/EC2/ELB/Route53, S3 bucket management, RDS management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ELB権限 (Load Balancer管理)
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:ModifyListener", # ALB Listener設定変更用（503エラー修正対応）
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:DescribeTargetHealth", # ローカル確認専用: ALBターゲットヘルス確認
          # GitHub Actions用の追加権限
          "elbv2:DescribeLoadBalancers",
          "elbv2:DeleteLoadBalancer",
          "elbv2:DescribeTargetGroups",
          "elbv2:DeleteTargetGroup",
          "elbv2:DescribeTargetHealth", # ローカル確認専用: ALBターゲットヘルス確認（v2 API）
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeLoadBalancerAttributes"
        ]
        Resource = "*"
      },
      {
        # EC2権限 (VPC, Subnet, SG, ENI)
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:DescribeRouteTables",
          # GitHub Actions用の追加権限
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        # S3バケット・オブジェクト操作権限
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging",
          "s3:DeleteBucketPolicy",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketAcl",
          "s3:GetBucketCors",
          "s3:GetBucketEncryption",
          "s3:GetBucketLifecycle",
          "s3:GetBucketLogging",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketReplication",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetBucketWebsite",
          "s3:PutBucketTagging",
          "s3:PutBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state"
        ]
      },
      {
        # CloudFrontディストリビューション・キャッシュ無効化権限
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListDistributions",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
          "cloudfront:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        # Route53権限（DNS管理・証明書検証用）
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      },
      {
        # RDS権限（PostgreSQL管理）
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:AddTagsToResource",
          "rds:ListTagsForResource",
          "rds:RemoveTagsFromResource",
          "rds:CreateDBSnapshot",
          "rds:DeleteDBSnapshot",
          "rds:DescribeDBSnapshots",
          "rds:RestoreDBInstanceFromDBSnapshot"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "hannibal_infrastructure_policy_attachment" {
  role       = aws_iam_role.hannibal_infrastructure_role.name
  policy_arn = aws_iam_policy.hannibal_infrastructure_policy.arn
}

# --- C. Monitoring Policy（監視権限）---
resource "aws_iam_role" "hannibal_monitoring_role" {
  name = "HannibalMonitoringRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::258632448142:user/hannibal",
            "arn:aws:iam::258632448142:role/HannibalCoreRole"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_policy" "hannibal_monitoring_policy" {
  name        = "HannibalMonitoringPolicy"
  description = "Monitoring permissions - CloudWatch Metrics/Alarms/Dashboard, SNS notifications, CloudTrail"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Alarms権限（監視・アラート）
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      },
      {
        # SNS権限（アラート通知） - 一時的に全権限
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = "*"
      },
      {
        # CloudWatch Dashboard権限（監視ダッシュボード）
        Effect = "Allow"
        Action = [
          "cloudwatch:PutDashboard",
          "cloudwatch:DeleteDashboards",
          "cloudwatch:ListDashboards",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        # CloudTrail権限（監査ログ）
        Effect = "Allow"
        Action = [
          "cloudtrail:CreateTrail",
          "cloudtrail:DeleteTrail",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetEventSelectors",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:ListTags",
          "cloudtrail:LookupEvents",
          "cloudtrail:PutEventSelectors",
          "cloudtrail:StartLogging"
        ]
        Resource = "*"
      },
      {
        # SES権限（メール送信）
        Effect = "Allow"
        Action = [
          "ses:GetSendQuota",
          "ses:ListIdentities"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "hannibal_monitoring_policy_attachment" {
  role       = aws_iam_role.hannibal_monitoring_role.name
  policy_arn = aws_iam_policy.hannibal_monitoring_policy.arn
}

# --- D. Security Policy（セキュリティ権限）---
resource "aws_iam_role" "hannibal_security_role" {
  name = "HannibalSecurityRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::258632448142:user/hannibal",
            "arn:aws:iam::258632448142:role/HannibalCoreRole"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_policy" "hannibal_security_policy" {
  name        = "HannibalSecurityPolicy"
  description = "Security permissions - ACM certificate management, KMS encryption, Access Analyzer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ACM証明書管理権限（独自ドメイン用）
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:DeleteCertificate",
          "acm:AddTagsToCertificate",
          "acm:ListTagsForCertificate",
          "acm:RemoveTagsFromCertificate"
        ]
        Resource = "*"
      },
      {
        # KMS権限（暗号化）
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        # Access Analyzer権限（権限分析）
        Effect = "Allow"
        Action = [
          "access-analyzer:CreateAnalyzer",
          "access-analyzer:DeleteAnalyzer",
          "access-analyzer:GetAnalyzer",
          "access-analyzer:ListFindings",
          "access-analyzer:GetFinding"
        ]
        Resource = "*"
      },
      {
        # S3 Terraform Stateファイルアクセス権限
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs",
          "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "hannibal_security_policy_attachment" {
  role       = aws_iam_role.hannibal_security_role.name
  policy_arn = aws_iam_policy.hannibal_security_policy.arn
}

# --- hannibalユーザーにAssumeRole権限のみをアタッチ ---
resource "aws_iam_policy" "hannibal_assume_role_policy" {
  name        = "HannibalAssumeRolePolicy"
  description = "Allow hannibal user to assume specific roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          aws_iam_role.hannibal_core_role.arn,
          aws_iam_role.hannibal_infrastructure_role.arn,
          aws_iam_role.hannibal_monitoring_role.arn,
          aws_iam_role.hannibal_security_role.arn
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "hannibal_assume_role_policy_attachment" {
  user       = "hannibal" # 直接ユーザー名を指定
  policy_arn = aws_iam_policy.hannibal_assume_role_policy.arn
}

# --- 既存のマネージドポリシーは不要になったため削除 ---
# resource "aws_iam_user_policy_attachment" "hannibal_ec2_full" { ... }
# resource "aws_iam_user_policy_attachment" "hannibal_ecs_full" { ... }

# --- IAM Role for ECS Task ---
# ECSタスクがAWSのサービス（例：ECRからイメージのpullなど）にアクセスするためのIAMロールを作成
# このロールは、ECSタスクがAWSのサービスを利用する際の認証に使用されます
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role" # プロジェクト名をプレフィックスとして使用

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

# --- ECS Cluster ---
# ECSクラスタを作成（Fargateタスクを実行するための論理的なグループ）
# クラスタは、タスクやサービスを論理的にグループ化するためのコンテナです
resource "aws_ecs_cluster" "main" {    # main は Terraformリソースのローカル名
  name = "${var.project_name}-cluster" # AWS上で作成される実際のクラスタの名前
}

# --- ECS Task Definition ---
# ECSタスクの定義（コンテナの設定、CPU、メモリ、環境変数など）
# タスク定義は、コンテナの実行に必要な設定を定義します
# タスク（Task）は、そのタスク定義をもとに実際に起動された「インスタンス」です
resource "aws_ecs_task_definition" "api" {                            # APIサーバ用のコンテナなので
  family                   = "${var.project_name}-api-task"           # タスク定義のファミリー名
  requires_compatibilities = ["FARGATE"]                              # Fargateで実行することを指定（サーバーレスコンピューティング）
  network_mode             = "awsvpc"                                 # Fargateではawsvpcモードが必須（AWS VPC CNIプラグインを使用）
  cpu                      = var.cpu                                  # タスクに割り当てるCPUユニット 1024ユニット = 1vCPU = 1スレッド（論理コア）相当
  memory                   = var.memory                               # タスクに割り当てるメモリ（MiB）
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # タスク実行用のIAMロール
  # IAMロールが付与されるのは、タスク定義から起動された「ECSタスク（コンテナ）」
  # ECSタスク　タスク定義（設計図）から実際に起動された「コンテナ群（1つ以上）」の実体 ＝ 実際に動いているアプリケーションのプロセス
  # ECS上で管理される　"arn:aws:ecs:ap-northeast-1:258632448142:task-definition/nestjs-hannibal-3-api-task:7"

  # (オプション) タスクロール (アプリケーションがAWSサービスにアクセスする場合)
  # task_role_arn            = aws_iam_role.ecs_task_role.arn # 別途作成

  # コンテナの定義（イメージ、ポート、環境変数など）
  # コンテナは、アプリケーションの実行環境を提供します
  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container" # コンテナ名
      image     = var.container_image_uri         # ECRから取得するDockerイメージ
      cpu       = var.cpu                         # コンテナに割り当てるCPUユニット
      memory    = var.memory                      # コンテナに割り当てるメモリ
      essential = true                            # このコンテナが必須かどうか
      portMappings = [
        {
          containerPort = var.container_port # コンテナ内部でリッスンしているアプリのポート番号と揃える
          hostPort      = var.container_port # ここでの「ホスト」は、Fargateタスクごとに割り当てられるENI（Elastic Network Interface）を指すと考えてください 
          protocol      = "tcp"
        } # 外部からの通信は、ENIのIPアドレス＋hostPortに届き、そこからcontainerPortにマッピングされてコンテナ内のアプリに届きます
      ]
      environment = [                                            # コンテナ内部のアプリに渡す環境変数
        { name = "PORT", value = tostring(var.container_port) }, # アプリケーションがリッスンするポート
        # tostring 値を文字列型に変換する関数 多くのアプリケーションや設定ファイルでは、環境変数の値は文字列として扱われるため

        { name = "HOST", value = "0.0.0.0" },
        # 0.0.0.0 アプリケーションは「そのコンテナに割り当てられているすべてのネットワークインターフェース（IPアドレス）」でリッスン（待ち受け）するという意味になります
        # 127.0.0.1 コンテナの中からしかアクセスできなくなります

        { name = "NODE_ENV", value = "production" },             # 本番環境
        { name = "CLIENT_URL", value = var.client_url_for_cors }, # CORS設定用のフロントエンドURL
        { name = "DATABASE_URL", value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/${var.db_name}?sslmode=require&sslrootcert=/opt/rds-ca-2019-root.pem" }
        # 他に必要な環境変数があれば追加
      ]
      logConfiguration = {    # CloudWatch Logs設定
        logDriver = "awslogs" # AWS CloudWatch Logsドライバーを使用
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-api-task" # ここでログストリームも自動で作られる
          "awslogs-region"        = var.aws_region                      # AWSリージョン
          "awslogs-stream-prefix" = "ecs"                               # ログストリームのプレフィックス
        }
      }
    }
  ])
}

# --- CloudWatch Log Group for ECS Task ---
# ECSタスクのログを保存するCloudWatch Logsのロググループを作成
# ロググループは、ログストリームをグループ化するためのコンテナです
resource "aws_cloudwatch_log_group" "ecs_api_task_logs" {
  name              = "/ecs/${var.project_name}-api-task" # ロググループ名
  retention_in_days = 7                                   # retention: 保持
}

# --- ALB (Application Load Balancer) ---
resource "aws_lb" "main" {
  name                       = "${var.project_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = data.aws_subnets.public.ids
  enable_deletion_protection = false
}

# --- ALB Target Group ---
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "ip"
  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 15
    matcher             = "200-399"
  }
}

# --- ALB Listener ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_listener_port
  protocol          = "HTTP"
  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.api.arn
      }
    }
  }
}

# --- Security Group for ALB ---
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = data.aws_vpc.selected.id
  ingress {
    from_port   = var.alb_listener_port
    to_port     = var.alb_listener_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security Group for ECS Service ---
resource "aws_security_group" "ecs_service_sg" {
  name        = "${var.project_name}-ecs-service-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = data.aws_vpc.selected.id
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- ECS Service ---
resource "aws_ecs_service" "api" {
  name                              = "${var.project_name}-api-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.api.arn
  desired_count                     = var.desired_task_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60
  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
  }
  depends_on = [aws_lb_listener.http, aws_db_instance.postgres]
}

# --- RDS Subnet Group ---
resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = data.aws_subnets.public.ids
  
  tags = {
    Name = "${var.project_name} DB subnet group"
  }
}

# --- Security Group for RDS ---
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL traffic from ECS"
  vpc_id      = data.aws_vpc.selected.id
  
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service_sg.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# --- RDS PostgreSQL Instance ---
resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = {
    Name = "${var.project_name}-postgres"
  }
}
