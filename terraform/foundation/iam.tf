# terraform/foundation/iam.tf
# 基盤IAMリソース（terraform/foundation で管理し、dev 環境 destroy から分離して永続保持）
# AWS Professional設計: Infrastructure as Code + 永続管理

data "aws_caller_identity" "current" {}

# --- 0. GitHub Actions OIDC Provider ---
# GitHub Actions が発行する短期トークンを AWS が検証するための IdP 登録
# 管理: terraform/foundation
# 参考: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# --- 新設計: 2ユーザー × 2ロール構成 ---

# --- 1. HannibalDeveloperRole-Dev (日常開発・アプリ運用ロール) ---
resource "aws_iam_role" "hannibal_developer_role" {
  name                 = "HannibalDeveloperRole-Dev"
  permissions_boundary = aws_iam_policy.hannibal_developer_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/hannibal"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-northeast-1"
          }
        }
      }
    ]
  })
}

# --- 2. HannibalCICDRole-Dev (自動デプロイロール) ---
# 信頼ポリシー: GitHub OIDC による AssumeRoleWithWebIdentity（長期キー不要）
# 許可範囲: kmryst/terraform-hannibal の main ブランチからの workflow_dispatch のみ
# 管理: terraform/foundation
resource "aws_iam_role" "hannibal_cicd_role" {
  name                 = "HannibalCICDRole-Dev"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/HannibalCICDBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:kmryst/terraform-hannibal:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

# --- 3. HannibalDeveloperPolicy-Dev (日常開発・アプリ運用ポリシー) ---
# #164 で wildcard から action 列挙に最小権限化済み。statements は local.hannibal_developer_policy_statements で管理。
resource "aws_iam_policy" "hannibal_developer_policy" {
  name        = "HannibalDeveloperPolicy-Dev"
  description = "Integrated development permissions - ECS/ECR/RDS/CloudWatch operations, limited Terraform execution"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.hannibal_developer_policy_statements
  })
}
# --- 4. HannibalDeveloperBoundary-Dev (日常開発ロール Permission Boundary) ---
# HannibalDeveloperRole-Dev の最大権限の上限。identity policy と同じ statements を共有し、
# Boundary が policy より広くなる状態を避ける。
resource "aws_iam_policy" "hannibal_developer_boundary" {
  name        = "HannibalDeveloperBoundary-Dev"
  description = "Permission Boundary for HannibalDeveloperRole-Dev: app operations only"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.hannibal_developer_policy_statements
  })
}

# --- 5. ポリシーアタッチメント ---
resource "aws_iam_role_policy_attachment" "hannibal_developer_policy_attachment" {
  role       = aws_iam_role.hannibal_developer_role.name
  policy_arn = aws_iam_policy.hannibal_developer_policy.arn
}


locals {
  hannibal_developer_policy_statements = [
    {
      Sid    = "DenyFoundationStateAccess"
      Effect = "Deny"
      Action = [
        "s3:*"
      ]
      Resource = [
        "arn:aws:s3:::nestjs-hannibal-3-terraform-state/foundation/*"
      ]
    },
    {
      Sid    = "ReadOperationalResources"
      Effect = "Allow"
      Action = [
        "cloudfront:Get*",
        "cloudfront:List*",
        "cloudwatch:Describe*",
        "cloudwatch:Get*",
        "cloudwatch:List*",
        "codedeploy:Get*",
        "codedeploy:List*",
        "ec2:Describe*",
        "ec2:Get*",
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:Describe*",
        "ecr:Get*",
        "ecr:List*",
        "ecs:Describe*",
        "ecs:List*",
        "elasticloadbalancing:Describe*",
        "iam:Get*",
        "iam:List*",
        "iam:SimulatePrincipalPolicy",
        "kms:Describe*",
        "kms:Get*",
        "kms:List*",
        "logs:Describe*",
        "logs:FilterLogEvents",
        "logs:Get*",
        "logs:GetQueryResults",
        "logs:List*",
        "logs:StartLiveTail",
        "logs:StartQuery",
        "logs:StopLiveTail",
        "logs:StopQuery",
        "rds:Describe*",
        "rds:List*",
        "resource-groups:Get*",
        "resource-groups:List*",
        "route53:Get*",
        "route53:List*",
        "secretsmanager:Describe*",
        "secretsmanager:List*",
        "sns:Get*",
        "sns:List*",
        "sts:DecodeAuthorizationMessage",
        "sts:GetCallerIdentity",
        "tag:Get*"
      ]
      Resource = "*"
    },
    {
      Sid      = "ECRAuthToken"
      Effect   = "Allow"
      Action   = "ecr:GetAuthorizationToken"
      Resource = "*"
    },
    {
      Sid    = "ECRPushPullApplicationRepository"
      Effect = "Allow"
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchDeleteImage",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetLifecyclePolicy",
        "ecr:InitiateLayerUpload",
        "ecr:ListImages",
        "ecr:ListTagsForResource",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ]
      Resource = "arn:aws:ecr:ap-northeast-1:${data.aws_caller_identity.current.account_id}:repository/nestjs-hannibal-3"
    },
    {
      Sid    = "ECSExecAndOperationalChange"
      Effect = "Allow"
      Action = [
        "ecs:DeregisterTaskDefinition",
        "ecs:ExecuteCommand",
        "ecs:RegisterTaskDefinition",
        "ecs:RunTask",
        "ecs:StopTask",
        "ecs:UpdateService",
        "ssm:DescribeSessions",
        "ssm:GetConnectionStatus",
        "ssm:StartSession",
        "ssm:TerminateSession",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    },
    {
      Sid    = "CodeDeployApplicationOperations"
      Effect = "Allow"
      Action = [
        "codedeploy:CreateDeployment",
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:StopDeployment"
      ]
      Resource = [
        "arn:aws:codedeploy:ap-northeast-1:${data.aws_caller_identity.current.account_id}:application:nestjs-hannibal-3-*",
        "arn:aws:codedeploy:ap-northeast-1:${data.aws_caller_identity.current.account_id}:deploymentgroup:nestjs-hannibal-3-*/nestjs-hannibal-3-*",
        "arn:aws:codedeploy:ap-northeast-1:${data.aws_caller_identity.current.account_id}:deploymentconfig:*"
      ]
    },
    {
      Sid    = "S3ProjectBucketRead"
      Effect = "Allow"
      Action = [
        "s3:Get*",
        "s3:List*"
      ]
      Resource = [
        "arn:aws:s3:::nestjs-hannibal-3-frontend",
        "arn:aws:s3:::nestjs-hannibal-3-frontend/*",
        "arn:aws:s3:::nestjs-hannibal-3-codedeploy-artifacts",
        "arn:aws:s3:::nestjs-hannibal-3-codedeploy-artifacts/*"
      ]
    },
    {
      Sid    = "S3ProjectObjectWrite"
      Effect = "Allow"
      Action = [
        "s3:DeleteObject",
        "s3:DeleteObjectTagging",
        "s3:GetObject",
        "s3:GetObjectTagging",
        "s3:PutObject",
        "s3:PutObjectTagging"
      ]
      Resource = [
        "arn:aws:s3:::nestjs-hannibal-3-frontend/*",
        "arn:aws:s3:::nestjs-hannibal-3-codedeploy-artifacts/*"
      ]
    },
    {
      Sid      = "TerraformDevStateBucketLocation"
      Effect   = "Allow"
      Action   = "s3:GetBucketLocation"
      Resource = "arn:aws:s3:::nestjs-hannibal-3-terraform-state"
    },
    {
      Sid      = "TerraformDevStateBucketList"
      Effect   = "Allow"
      Action   = "s3:ListBucket"
      Resource = "arn:aws:s3:::nestjs-hannibal-3-terraform-state"
      Condition = {
        StringLike = {
          "s3:prefix" = [
            "environments/dev/",
            "environments/dev/terraform.tfstate",
            "environments/dev/terraform.tfstate.tflock"
          ]
        }
      }
    },
    {
      Sid      = "TerraformDevStateObjectRead"
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "arn:aws:s3:::nestjs-hannibal-3-terraform-state/environments/dev/terraform.tfstate"
    },
    {
      Sid    = "TerraformDevStateLockfileWrite"
      Effect = "Allow"
      Action = [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::nestjs-hannibal-3-terraform-state/environments/dev/terraform.tfstate.tflock"
    },
    {
      Sid      = "TerraformDevStateLockTableDescribe"
      Effect   = "Allow"
      Action   = "dynamodb:DescribeTable"
      Resource = "arn:aws:dynamodb:ap-northeast-1:${data.aws_caller_identity.current.account_id}:table/terraform-state-lock"
    },
    {
      Sid    = "TerraformDevStateLockItems"
      Effect = "Allow"
      Action = [
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:PutItem"
      ]
      Resource = "arn:aws:dynamodb:ap-northeast-1:${data.aws_caller_identity.current.account_id}:table/terraform-state-lock"
      Condition = {
        StringLike = {
          "dynamodb:LeadingKeys" = "nestjs-hannibal-3-terraform-state/environments/dev/terraform.tfstate*"
        }
      }
    },
    {
      Sid    = "SecretsManagerReadForApplicationDebug"
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecretVersionIds"
      ]
      Resource = [
        "arn:aws:secretsmanager:ap-northeast-1:${data.aws_caller_identity.current.account_id}:secret:nestjs-hannibal-3*",
        "arn:aws:secretsmanager:ap-northeast-1:${data.aws_caller_identity.current.account_id}:secret:rds!*"
      ]
    },
    {
      Sid    = "KMSDecryptForApplicationSecrets"
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      Resource = "arn:aws:kms:ap-northeast-1:${data.aws_caller_identity.current.account_id}:key/*"
      Condition = {
        StringEquals = {
          "kms:ViaService" = "secretsmanager.ap-northeast-1.amazonaws.com"
        }
      }
    },
    {
      Sid      = "PassECSTaskExecutionRoleOnly"
      Effect   = "Allow"
      Action   = "iam:PassRole"
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nestjs-hannibal-3-ecs-task-execution-role"
      Condition = {
        StringEquals = {
          "iam:PassedToService" = "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}

# --- 6. HannibalCICDBoundary (CI/CD専用Permission Boundary) ---
# HannibalCICDRole-Dev の最大権限を制限する Permission Boundary。
# #166 にて Terraform 管理に移行。不使用サービスへの明示 Deny を追加済み。
resource "aws_iam_policy" "hannibal_cicd_boundary" {
  name = "HannibalCICDBoundary"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCICDServices"
        Effect = "Allow"
        Action = [
          "access-analyzer:*",
          "cloudtrail:*",
          "ec2:*",
          "ecr:*",
          "ecs:*",
          "elasticloadbalancing:*",
          "logs:*",
          "cloudwatch:*",
          "rds:*",
          "secretsmanager:*",
          "s3:*",
          "sns:*",
          "sts:*",
          "kms:*",
          "iam:GetRole", "iam:PassRole", "iam:CreateRole", "iam:DeleteRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies", "iam:GetRolePolicy",
          "iam:ListRolePolicies", "iam:CreatePolicy", "iam:DeletePolicy",
          "iam:TagPolicy", "iam:UntagPolicy", "iam:GetPolicy",
          "iam:GetPolicyVersion", "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion", "iam:ListRoles", "iam:UpdateRole",
          "iam:TagRole", "iam:UntagRole", "iam:ListInstanceProfiles",
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:ListInstanceProfilesForRole",
          "cloudfront:*",
          "route53:*",
          "codedeploy:*",
          "dynamodb:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyUnusedServicesAndIAMEscalation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser", "iam:DeleteUser",
          "iam:CreateAccessKey", "iam:DeleteAccessKey",
          "organizations:*",
          "account:*",
          "lambda:*",
          "cognito-idp:*", "cognito-identity:*",
          "sagemaker:*", "bedrock:*",
          "ec2:RunInstances", "ec2:StartInstances", "ec2:TerminateInstances",
        ]
        Resource = "*"
      },
    ]
  })
}

# --- 7. HannibalECSBoundary (ECSアプリIAM用Permission Boundary) ---
# ECS Task Execution Role 本体とアプリ用Secrets read policyは terraform/environments/dev 管理。
# この Boundary は deploy 前から存在する永続ガードレールとして foundation で管理する。
resource "aws_iam_policy" "hannibal_ecs_boundary" {
  name        = "HannibalECSBoundary"
  description = "Permission Boundary for ECS Task Execution Role - Hannibal Project"

  policy = file("${path.module}/HannibalECSBoundary.json")
}

# --- 8. HannibalCICDPolicy-Dev-* (CI/CD最小権限ポリシー・3分割) ---
# IAMマネージドポリシーの6144文字制限により compute/storage/deploy の3ポリシーに分割。
# candidate での deploy/destroy 検証完了後（#166）に正式採用。

# compute: EC2/VPC, ECR, ECS, ELB
resource "aws_iam_policy" "hannibal_cicd_policy_compute" {
  name        = "HannibalCICDPolicy-Dev-compute"
  description = "CI/CD permissions for compute resources - EC2/VPC, ECR, ECS, ELB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VPCAndNetworking"
        Effect = "Allow"
        Action = [
          "ec2:AllocateAddress", "ec2:AssociateRouteTable", "ec2:AttachInternetGateway",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateInternetGateway", "ec2:CreateNatGateway", "ec2:CreateRoute",
          "ec2:CreateRouteTable", "ec2:CreateSecurityGroup", "ec2:CreateSubnet",
          "ec2:CreateTags", "ec2:CreateVpc", "ec2:DeleteInternetGateway",
          "ec2:DeleteNatGateway", "ec2:DeleteRouteTable", "ec2:DeleteSecurityGroup",
          "ec2:DeleteSubnet", "ec2:DeleteTags", "ec2:DeleteVpc",
          "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses", "ec2:DescribeAddressesAttribute",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeInternetGateways", "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkAcls", "ec2:DescribeNetworkInterfaces", "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcs", "ec2:DetachInternetGateway", "ec2:DisassociateAddress",
          "ec2:DisassociateRouteTable", "ec2:GetSecurityGroupsForVpc",
          "ec2:ModifySubnetAttribute", "ec2:ModifyVpcAttribute",
          "ec2:ReleaseAddress", "ec2:RevokeSecurityGroupEgress",
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRWrite"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:BatchDeleteImage", "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload", "ecr:DeleteLifecyclePolicy", "ecr:DescribeImages",
          "ecr:DescribeRepositories", "ecr:GetLifecyclePolicy", "ecr:InitiateLayerUpload",
          "ecr:ListImages", "ecr:ListTagsForResource", "ecr:PutImage",
          "ecr:PutLifecyclePolicy", "ecr:TagResource", "ecr:UntagResource", "ecr:UploadLayerPart",
        ]
        Resource = "arn:aws:ecr:ap-northeast-1:${data.aws_caller_identity.current.account_id}:repository/nestjs-hannibal-3"
      },
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECSCluster"
        Effect = "Allow"
        Action = [
          "ecs:CreateCluster", "ecs:DeleteCluster", "ecs:DescribeClusters",
          "ecs:ListClusters", "ecs:PutClusterCapacityProviders", "ecs:TagResource", "ecs:UntagResource",
        ]
        Resource = "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:cluster/nestjs-hannibal-3-*"
      },
      {
        Sid      = "ECSService"
        Effect   = "Allow"
        Action   = ["ecs:CreateService", "ecs:DeleteService", "ecs:DescribeServices", "ecs:UpdateService"]
        Resource = "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:service/nestjs-hannibal-3-*/*"
      },
      {
        Sid    = "ECSTaskDefinition"
        Effect = "Allow"
        Action = [
          "ecs:DeregisterTaskDefinition", "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions", "ecs:RegisterTaskDefinition",
          "ecs:TagResource", "ecs:UntagResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "ELB"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags", "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:DeleteTargetGroup", "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerAttributes", "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes", "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTags", "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes", "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:RemoveTags",
        ]
        Resource = "*"
      },
    ]
  })
}

# storage: S3, RDS, DynamoDB, SecretsManager, KMS
resource "aws_iam_policy" "hannibal_cicd_policy_storage" {
  name        = "HannibalCICDPolicy-Dev-storage"
  description = "CI/CD permissions for storage resources - S3, RDS, DynamoDB, SecretsManager, KMS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3FrontendAndArtifacts"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket", "s3:DeleteBucketPolicy",
          "s3:DeleteBucketPublicAccessBlock", "s3:GetBucketAcl", "s3:GetBucketCORS",
          "s3:GetBucketLocation", "s3:GetBucketLogging", "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketPolicy", "s3:GetBucketPublicAccessBlock", "s3:GetBucketRequestPayment",
          "s3:GetBucketTagging", "s3:GetBucketVersioning", "s3:GetBucketWebsite",
          "s3:GetEncryptionConfiguration", "s3:GetLifecycleConfiguration",
          "s3:GetReplicationConfiguration", "s3:GetAccelerateConfiguration",
          "s3:ListBucket", "s3:ListBucketVersions", "s3:PutBucketPolicy", "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketTagging", "s3:PutBucketVersioning", "s3:PutEncryptionConfiguration",
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-frontend",
          "arn:aws:s3:::nestjs-hannibal-3-codedeploy-artifacts",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
        ]
      },
      {
        Sid    = "S3Object"
        Effect = "Allow"
        Action = [
          "s3:DeleteObject", "s3:DeleteObjectTagging", "s3:DeleteObjectVersion", "s3:GetObject",
          "s3:GetObjectTagging", "s3:PutObject", "s3:PutObjectTagging",
        ]
        Resource = [
          "arn:aws:s3:::nestjs-hannibal-3-frontend/*",
          "arn:aws:s3:::nestjs-hannibal-3-codedeploy-artifacts/*",
          "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
        ]
      },
      {
        Sid      = "S3List"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
      },
      {
        Sid    = "RDSInstance"
        Effect = "Allow"
        Action = [
          "rds:AddTagsToResource", "rds:CreateDBInstance", "rds:CreateDBParameterGroup",
          "rds:CreateDBSubnetGroup", "rds:DeleteDBInstance", "rds:DeleteDBParameterGroup",
          "rds:DeleteDBSubnetGroup", "rds:DescribeDBParameterGroups",
          "rds:DescribeDBParameters", "rds:DescribeDBSubnetGroups", "rds:ListTagsForResource",
          "rds:ModifyDBParameterGroup", "rds:RemoveTagsFromResource", "rds:ResetDBParameterGroup",
        ]
        Resource = [
          "arn:aws:rds:ap-northeast-1:${data.aws_caller_identity.current.account_id}:db:nestjs-hannibal-3-*",
          "arn:aws:rds:ap-northeast-1:${data.aws_caller_identity.current.account_id}:subgrp:nestjs-hannibal-3-*",
          "arn:aws:rds:ap-northeast-1:${data.aws_caller_identity.current.account_id}:pg:nestjs-hannibal-3-*",
        ]
      },
      {
        Sid      = "RDSDescribeAll"
        Effect   = "Allow"
        Action   = ["rds:DescribeDBInstances"]
        Resource = "*"
      },
      {
        Sid      = "DynamoDBTerraformLock"
        Effect   = "Allow"
        Action   = ["dynamodb:DeleteItem", "dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem"]
        Resource = "arn:aws:dynamodb:ap-northeast-1:${data.aws_caller_identity.current.account_id}:table/terraform-state-lock"
      },
      {
        Sid    = "SecretsManagerForRDS"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret", "secretsmanager:DescribeSecret",
          "secretsmanager:GetResourcePolicy", "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecretVersionIds", "secretsmanager:PutResourcePolicy",
          "secretsmanager:TagResource", "secretsmanager:UntagResource",
        ]
        Resource = [
          "arn:aws:secretsmanager:ap-northeast-1:${data.aws_caller_identity.current.account_id}:secret:nestjs-hannibal-3*",
          "arn:aws:secretsmanager:ap-northeast-1:${data.aws_caller_identity.current.account_id}:secret:rds!*",
        ]
      },
      {
        Sid      = "KMSGrantForSecretsAndLogs"
        Effect   = "Allow"
        Action   = ["kms:CreateGrant", "kms:DescribeKey"]
        Resource = "arn:aws:kms:ap-northeast-1:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "secretsmanager.ap-northeast-1.amazonaws.com",
              "logs.ap-northeast-1.amazonaws.com",
              "ecr.ap-northeast-1.amazonaws.com",
              "rds.ap-northeast-1.amazonaws.com",
              "s3.ap-northeast-1.amazonaws.com",
            ]
          }
        }
      },
    ]
  })
}

# deploy: CloudWatch, Logs, CloudFront, Route53, CodeDeploy, SNS, CloudTrail, AccessAnalyzer, STS, IAM
resource "aws_iam_policy" "hannibal_cicd_policy_deploy" {
  name        = "HannibalCICDPolicy-Dev-deploy"
  description = "CI/CD permissions for deploy operations - CloudWatch, Logs, CloudFront, Route53, CodeDeploy, SNS, CloudTrail, IAM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:DescribeLogStreams", "logs:ListTagsForResource", "logs:PutRetentionPolicy",
          "logs:TagLogGroup", "logs:TagResource", "logs:UntagLogGroup", "logs:UntagResource",
        ]
        Resource = [
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/ecs/nestjs-hannibal-3-*",
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/ecs/nestjs-hannibal-3-*:*",
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/codedeploy/nestjs-hannibal-3-*",
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/codedeploy/nestjs-hannibal-3-*:*",
        ]
      },
      {
        Sid      = "CloudWatchLogsDescribeAll"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchAlarm"
        Effect = "Allow"
        Action = [
          "cloudwatch:DeleteAlarms", "cloudwatch:DeleteDashboards", "cloudwatch:DescribeAlarms",
          "cloudwatch:GetDashboard", "cloudwatch:ListMetrics", "cloudwatch:ListTagsForResource",
          "cloudwatch:PutDashboard", "cloudwatch:PutMetricAlarm", "cloudwatch:TagResource", "cloudwatch:UntagResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudFront"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution", "cloudfront:CreateInvalidation", "cloudfront:CreateOriginAccessControl",
          "cloudfront:DeleteDistribution", "cloudfront:DeleteOriginAccessControl",
          "cloudfront:GetDistribution", "cloudfront:GetDistributionConfig", "cloudfront:GetInvalidation",
          "cloudfront:GetOriginAccessControl", "cloudfront:ListDistributions", "cloudfront:ListInvalidations",
          "cloudfront:ListOriginAccessControls", "cloudfront:ListTagsForResource",
          "cloudfront:TagResource", "cloudfront:UntagResource",
          "cloudfront:UpdateDistribution", "cloudfront:UpdateOriginAccessControl",
        ]
        Resource = "*"
      },
      {
        Sid    = "Route53"
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets", "route53:GetChange", "route53:GetHostedZone",
          "route53:ListHostedZones", "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets", "route53:ListTagsForResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "CodeDeploy"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateApplication", "codedeploy:CreateDeployment", "codedeploy:CreateDeploymentGroup",
          "codedeploy:DeleteApplication", "codedeploy:DeleteDeploymentGroup",
          "codedeploy:GetApplication", "codedeploy:GetDeployment", "codedeploy:GetDeploymentConfig",
          "codedeploy:GetDeploymentGroup",
          "codedeploy:ListApplications", "codedeploy:ListDeploymentGroups", "codedeploy:ListDeployments",
          "codedeploy:ListTagsForResource", "codedeploy:RegisterApplicationRevision", "codedeploy:StopDeployment",
          "codedeploy:TagResource", "codedeploy:UntagResource", "codedeploy:UpdateDeploymentGroup",
        ]
        Resource = [
          "arn:aws:codedeploy:ap-northeast-1:${data.aws_caller_identity.current.account_id}:application:nestjs-hannibal-3-*",
          "arn:aws:codedeploy:ap-northeast-1:${data.aws_caller_identity.current.account_id}:deploymentgroup:nestjs-hannibal-3-*/nestjs-hannibal-3-*",
          "arn:aws:codedeploy:ap-northeast-1:${data.aws_caller_identity.current.account_id}:deploymentconfig:*",
        ]
      },
      {
        Sid    = "SNS"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic", "sns:DeleteTopic", "sns:GetSubscriptionAttributes",
          "sns:GetTopicAttributes", "sns:ListSubscriptionsByTopic", "sns:ListTagsForResource",
          "sns:ListTopics", "sns:SetTopicAttributes", "sns:Subscribe",
          "sns:TagResource", "sns:UntagResource", "sns:Unsubscribe",
        ]
        Resource = "arn:aws:sns:ap-northeast-1:${data.aws_caller_identity.current.account_id}:nestjs-hannibal-3-*"
      },
      {
        Sid    = "CloudTrail"
        Effect = "Allow"
        Action = [
          "cloudtrail:AddTags", "cloudtrail:CreateTrail", "cloudtrail:DeleteTrail",
          "cloudtrail:DescribeTrails", "cloudtrail:GetTrailStatus", "cloudtrail:ListTags",
          "cloudtrail:PutEventSelectors", "cloudtrail:RemoveTags", "cloudtrail:StartLogging",
        ]
        Resource = "arn:aws:cloudtrail:ap-northeast-1:${data.aws_caller_identity.current.account_id}:trail/nestjs-hannibal-3-*"
      },
      {
        Sid    = "AccessAnalyzer"
        Effect = "Allow"
        Action = [
          "access-analyzer:CreateAnalyzer", "access-analyzer:DeleteAnalyzer",
          "access-analyzer:GetAnalyzer", "access-analyzer:ListAnalyzers",
          "access-analyzer:TagResource", "access-analyzer:UntagResource",
        ]
        Resource = "*"
      },
      {
        Sid      = "STSReadOnly"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
      {
        Sid    = "IAMRolePolicyForProjectRolesOnly"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy", "iam:CreateRole", "iam:DeleteRole",
          "iam:DeleteRolePermissionsBoundary", "iam:DeleteRolePolicy", "iam:DetachRolePolicy",
          "iam:GetRole", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole", "iam:ListRolePolicies", "iam:PutRolePolicy",
          "iam:PutRolePermissionsBoundary", "iam:TagRole", "iam:UntagRole", "iam:UpdateAssumeRolePolicy",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nestjs-hannibal-3-*"
      },
      {
        Sid    = "IAMPolicyForProjectPoliciesOnly"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicy",
          "iam:DeletePolicyVersion", "iam:GetPolicy", "iam:GetPolicyVersion",
          "iam:ListPolicyVersions", "iam:SetDefaultPolicyVersion", "iam:TagPolicy", "iam:UntagPolicy",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/nestjs-hannibal-3-*"
      },
      {
        Sid      = "IAMPassRoleForECSTaskExecutionOnly"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nestjs-hannibal-3-ecs-task-execution-role"
        Condition = {
          StringEquals = { "iam:PassedToService" = ["ecs-tasks.amazonaws.com"] }
        }
      },
      {
        Sid      = "IAMPassRoleForCodeDeployOnly"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nestjs-hannibal-3-codedeploy-service-role"
        Condition = {
          StringEquals = { "iam:PassedToService" = ["codedeploy.amazonaws.com"] }
        }
      },
      {
        Sid      = "IAMReadOnlyForCheck"
        Effect   = "Allow"
        Action   = ["iam:SimulatePrincipalPolicy", "iam:ListRoles", "iam:ListPolicies"]
        Resource = "*"
      },
    ]
  })
}

# --- 8. ポリシーアタッチメント (CICD) ---
resource "aws_iam_role_policy_attachment" "hannibal_cicd_compute_attachment" {
  role       = "HannibalCICDRole-Dev"
  policy_arn = aws_iam_policy.hannibal_cicd_policy_compute.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_cicd_storage_attachment" {
  role       = "HannibalCICDRole-Dev"
  policy_arn = aws_iam_policy.hannibal_cicd_policy_storage.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_cicd_deploy_attachment" {
  role       = "HannibalCICDRole-Dev"
  policy_arn = aws_iam_policy.hannibal_cicd_policy_deploy.arn
}

# --- 7. HannibalPRPlanBoundary-Dev (PR terraform plan専用Permission Boundary) ---
# PR plan role の最大権限を read/list/describe/get 系に制限する。
# iam:PassRole / create・update・delete・put・modify・attach・detach 系 /
# s3:PutObject・DeleteObject / secretsmanager:GetSecretValue は含めない。
resource "aws_iam_policy" "hannibal_pr_plan_boundary" {
  name        = "HannibalPRPlanBoundary-Dev"
  description = "Permission boundary for PR terraform plan role - read/list/describe/get only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformPlanReadOnlyBoundary"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "ecr:DescribeRepositories",
          "ecr:GetLifecyclePolicy",
          "ecr:ListTagsForResource",
          "rds:Describe*",
          "rds:ListTagsForResource",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:ListTagsForResource",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListTagsForResource",
          "sns:GetTopicAttributes",
          "sns:GetSubscriptionAttributes",
          "sns:ListSubscriptionsByTopic",
          "sns:ListTagsForResource",
          "sns:ListTopics",
          "codedeploy:Get*",
          "codedeploy:List*",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:ListInstanceProfilesForRole",
          "s3:Get*",
          "s3:List*",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListTagsForResource",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:ListSecretVersionIds",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- 8. HannibalPRPlanRole-Dev (PR terraform plan専用ロール) ---
# 信頼ポリシー: GitHub OIDC による AssumeRoleWithWebIdentity
# 許可範囲: kmryst/terraform-hannibal への pull_request イベントのみ
# 用途: PR Check での terraform plan 実行（read-only、apply/destroy 権限なし）
# 設計詳細: docs/operations/pr-terraform-plan-role-design.md
# Permission Boundary: HannibalPRPlanBoundary-Dev を付与する。
#   既存の HannibalCICDBoundary は deploy/destroy 用で流用不適。
resource "aws_iam_role" "hannibal_pr_plan_role" {
  name                 = "HannibalPRPlanRole-Dev"
  permissions_boundary = aws_iam_policy.hannibal_pr_plan_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:kmryst/terraform-hannibal:pull_request"
          }
        }
      }
    ]
  })
}

# --- 9. HannibalPRPlanPolicy-Dev (PR terraform plan専用ポリシー) ---
# terraform plan に必要な read/list/describe/get 権限のみ
# 含めない: iam:PassRole / create・update・delete・put・modify 系 /
#           s3:PutObject・DeleteObject / dynamodb:PutItem・DeleteItem /
#           secretsmanager:GetSecretValue / ECR push・upload 系
resource "aws_iam_policy" "hannibal_pr_plan_policy" {
  name        = "HannibalPRPlanPolicy-Dev"
  description = "Read-only permissions for PR terraform plan - describe/list/get only, no write or apply operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformPlanRead"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "ecr:DescribeRepositories",
          "ecr:GetLifecyclePolicy",
          "ecr:ListTagsForResource",
          "rds:Describe*",
          "rds:ListTagsForResource",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:ListTagsForResource",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListTagsForResource",
          "sns:GetTopicAttributes",
          "sns:GetSubscriptionAttributes",
          "sns:ListSubscriptionsByTopic",
          "sns:ListTagsForResource",
          "sns:ListTopics",
          "codedeploy:Get*",
          "codedeploy:List*",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:ListInstanceProfilesForRole",
          "s3:Get*",
          "s3:List*",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListTagsForResource",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:ListSecretVersionIds",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid      = "TerraformStateRead"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::nestjs-hannibal-3-terraform-state/environments/dev/terraform.tfstate"
      }
    ]
  })
}

# --- 10. Policy Attachment (PR plan) ---
resource "aws_iam_role_policy_attachment" "hannibal_pr_plan_policy_attachment" {
  role       = aws_iam_role.hannibal_pr_plan_role.name
  policy_arn = aws_iam_policy.hannibal_pr_plan_policy.arn
}

# --- 11. HannibalFoundationRole-Dev (terraform/foundation apply専用ロール) ---
# 用途: IAM / OIDC / Permission Boundary / CloudTrail / Athena / Budgets など
#       「インフラのインフラ」を更新する terraform/foundation apply 専用。
# HannibalDeveloperRole-Dev は日常開発・アプリ運用に寄せるため、foundation apply
# 用の高権限操作はこのロールへ分離する。

locals {
  hannibal_foundation_approved_boundary_arn_pattern = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Hannibal*Boundary*"

  hannibal_foundation_boundary_statements = [
    {
      Sid    = "DenyFoundationBoundaryPolicyMutation"
      Effect = "Deny"
      Action = [
        "iam:CreatePolicyVersion",
        "iam:DeletePolicy",
        "iam:DeletePolicyVersion",
        "iam:SetDefaultPolicyVersion"
      ]
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/HannibalFoundationBoundary-Dev"
    },
    {
      Sid      = "DenyRemovingHannibalRoleBoundaries"
      Effect   = "Deny"
      Action   = "iam:DeleteRolePermissionsBoundary"
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Hannibal*"
    },
    {
      Sid    = "AllowIAMFoundationServices"
      Effect = "Allow"
      Action = [
        "iam:AddClientIDToOpenIDConnectProvider",
        "iam:AttachRolePolicy",
        "iam:CreateOpenIDConnectProvider",
        "iam:CreatePolicy",
        "iam:CreatePolicyVersion",
        "iam:CreateRole",
        "iam:DeleteOpenIDConnectProvider",
        "iam:DeletePolicy",
        "iam:DeletePolicyVersion",
        "iam:DeleteRole",
        "iam:DeleteRolePolicy",
        "iam:DetachRolePolicy",
        "iam:Get*",
        "iam:List*",
        "iam:PassRole",
        "iam:PutRolePermissionsBoundary",
        "iam:PutRolePolicy",
        "iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:SetDefaultPolicyVersion",
        "iam:UpdateAssumeRolePolicy",
        "iam:UpdateOpenIDConnectProviderThumbprint",
        "iam:UpdateRole"
      ]
      Resource = "*"
    },
    {
      Sid    = "AllowFoundationS3StateAndAthenaResults"
      Effect = "Allow"
      Action = [
        "s3:DeleteObject",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject"
      ]
      Resource = [
        "arn:aws:s3:::nestjs-hannibal-3-terraform-state",
        "arn:aws:s3:::nestjs-hannibal-3-terraform-state/*",
        "arn:aws:s3:::nestjs-hannibal-3-athena-results",
        "arn:aws:s3:::nestjs-hannibal-3-athena-results/*"
      ]
    },
    {
      Sid    = "AllowFoundationManagedS3Buckets"
      Effect = "Allow"
      Action = [
        "s3:CreateBucket",
        "s3:DeleteBucket*",
        "s3:Get*",
        "s3:List*",
        "s3:PutBucket*",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration"
      ]
      Resource = [
        "arn:aws:s3:::nestjs-hannibal-3-athena-results",
        "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs"
      ]
    },
    {
      Sid    = "AllowCloudTrailLogsBucketPolicy"
      Effect = "Allow"
      Action = [
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy"
      ]
      Resource = "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs"
    },
    {
      Sid    = "AllowFoundationDynamoDBLock"
      Effect = "Allow"
      Action = [
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem"
      ]
      Resource = "arn:aws:dynamodb:ap-northeast-1:${data.aws_caller_identity.current.account_id}:table/terraform-state-lock"
    },
    {
      Sid    = "AllowFoundationManagedServices"
      Effect = "Allow"
      Action = [
        "athena:*",
        "budgets:*",
        "cloudwatch:*",
        "cloudtrail:*",
        "glue:*",
        "guardduty:*",
        "logs:*",
        "sns:*",
        "sts:GetCallerIdentity"
      ]
      Resource = "*"
    },
  ]

  hannibal_foundation_all_policy_statements = [
    {
      Sid    = "DenyFoundationBoundaryPolicyMutation"
      Effect = "Deny"
      Action = [
        "iam:CreatePolicyVersion",
        "iam:DeletePolicy",
        "iam:DeletePolicyVersion",
        "iam:SetDefaultPolicyVersion"
      ]
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/HannibalFoundationBoundary-Dev"
    },
    {
      Sid      = "DenyRemovingHannibalRoleBoundaries"
      Effect   = "Deny"
      Action   = "iam:DeleteRolePermissionsBoundary"
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Hannibal*"
    },
    {
      Sid    = "ReadHannibalIAMResources"
      Effect = "Allow"
      Action = [
        "iam:Get*",
        "iam:List*"
      ]
      Resource = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Hannibal*",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Hannibal*",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      ]
    },
    {
      Sid    = "CreateOrSetApprovedHannibalRoleBoundaries"
      Effect = "Allow"
      Action = [
        "iam:CreateRole",
        "iam:PutRolePermissionsBoundary"
      ]
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Hannibal*"
      Condition = {
        ArnLike = {
          "iam:PermissionsBoundary" = local.hannibal_foundation_approved_boundary_arn_pattern
        }
      }
    },
    {
      Sid    = "ManageApprovedBoundaryHannibalRoles"
      Effect = "Allow"
      Action = [
        "iam:DeleteRole",
        "iam:UpdateRole",
        "iam:UpdateAssumeRolePolicy"
      ]
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Hannibal*"
      Condition = {
        ArnLike = {
          "iam:PermissionsBoundary" = local.hannibal_foundation_approved_boundary_arn_pattern
        }
      }
    },
    {
      Sid    = "ManageApprovedBoundaryHannibalRolePolicies"
      Effect = "Allow"
      Action = [
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy"
      ]
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Hannibal*"
      Condition = {
        ArnLike = {
          "iam:PermissionsBoundary" = local.hannibal_foundation_approved_boundary_arn_pattern
        }
      }
    },
    {
      Sid    = "ManageApprovedHannibalPolicyAttachments"
      Effect = "Allow"
      Action = [
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy"
      ]
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Hannibal*"
      Condition = {
        ArnLike = {
          "iam:PermissionsBoundary" = local.hannibal_foundation_approved_boundary_arn_pattern
          "iam:PolicyARN"           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Hannibal*"
        }
      }
    },
    {
      Sid    = "ManageHannibalManagedPolicies"
      Effect = "Allow"
      Action = [
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:SetDefaultPolicyVersion"
      ]
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Hannibal*"
    },
    {
      Sid    = "ManageGitHubOIDCProvider"
      Effect = "Allow"
      Action = [
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:UpdateOpenIDConnectProviderThumbprint",
        "iam:AddClientIDToOpenIDConnectProvider",
        "iam:RemoveClientIDFromOpenIDConnectProvider"
      ]
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
    },
    {
      Sid      = "PassCloudTrailCloudWatchLogsRole"
      Effect   = "Allow"
      Action   = "iam:PassRole"
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/HannibalCloudTrailCloudWatchLogsRole-Dev"
      Condition = {
        StringEquals = {
          "iam:PassedToService" = "cloudtrail.amazonaws.com"
        }
      }
    },
    {
      Sid    = "ListIAMFoundationResources"
      Effect = "Allow"
      Action = [
        "iam:GetAccountSummary",
        "iam:ListRoles",
        "iam:ListPolicies",
        "iam:ListOpenIDConnectProviders"
      ]
      Resource = "*"
    },
    {
      Sid      = "TerraformFoundationStateBucketLocation"
      Effect   = "Allow"
      Action   = "s3:GetBucketLocation"
      Resource = "arn:aws:s3:::nestjs-hannibal-3-terraform-state"
    },
    {
      Sid      = "TerraformFoundationStateBucketList"
      Effect   = "Allow"
      Action   = "s3:ListBucket"
      Resource = "arn:aws:s3:::nestjs-hannibal-3-terraform-state"
      Condition = {
        StringLike = {
          "s3:prefix" = [
            "foundation/",
            "foundation/terraform.tfstate",
            "foundation/terraform.tfstate.tflock"
          ]
        }
      }
    },
    {
      Sid    = "TerraformFoundationStateObject"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      Resource = [
        "arn:aws:s3:::nestjs-hannibal-3-terraform-state/foundation/terraform.tfstate",
        "arn:aws:s3:::nestjs-hannibal-3-terraform-state/foundation/terraform.tfstate.tflock"
      ]
    },
    {
      Sid    = "TerraformFoundationStateLock"
      Effect = "Allow"
      Action = [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ]
      Resource = "arn:aws:dynamodb:ap-northeast-1:${data.aws_caller_identity.current.account_id}:table/terraform-state-lock"
    },
    {
      Sid    = "ManageAthenaFoundation"
      Effect = "Allow"
      Action = [
        "athena:CreateWorkGroup",
        "athena:DeleteWorkGroup",
        "athena:GetWorkGroup",
        "athena:UpdateWorkGroup",
        "athena:ListWorkGroups",
        "athena:CreateNamedQuery",
        "athena:DeleteNamedQuery",
        "athena:GetDatabase",
        "athena:GetNamedQuery",
        "athena:BatchGetNamedQuery",
        "athena:ListNamedQueries",
        "athena:StartQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults",
        "athena:TagResource",
        "athena:UntagResource",
        "athena:ListTagsForResource",
        "glue:CreateDatabase",
        "glue:CreateTable",
        "glue:DeleteDatabase",
        "glue:DeleteTable",
        "glue:GetDatabase",
        "glue:GetDatabases",
        "glue:GetTable",
        "glue:GetTables",
        "glue:UpdateDatabase",
        "glue:UpdateTable",
        "glue:TagResource",
        "glue:UntagResource",
        "glue:GetTags"
      ]
      Resource = "*"
    },
    {
      Sid    = "AthenaResultsBucket"
      Effect = "Allow"
      Action = [
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ]
      Resource = "arn:aws:s3:::nestjs-hannibal-3-athena-results"
    },
    {
      Sid    = "AthenaResultsObjects"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      Resource = "arn:aws:s3:::nestjs-hannibal-3-athena-results/*"
    },
    {
      Sid    = "ManageFoundationS3Buckets"
      Effect = "Allow"
      Action = [
        "s3:CreateBucket",
        "s3:DeleteBucket*",
        "s3:Get*",
        "s3:List*",
        "s3:PutBucket*",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration"
      ]
      Resource = [
        "arn:aws:s3:::nestjs-hannibal-3-athena-results",
        "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs"
      ]
    },
    {
      Sid    = "ManageCloudTrailFoundation"
      Effect = "Allow"
      Action = [
        "cloudtrail:CreateTrail",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail",
        "cloudtrail:DescribeTrails",
        "cloudtrail:GetTrail",
        "cloudtrail:GetTrailStatus",
        "cloudtrail:GetEventSelectors",
        "cloudtrail:ListTrails",
        "cloudtrail:ListTags",
        "cloudtrail:PutEventSelectors",
        "cloudtrail:StartLogging",
        "cloudtrail:StopLogging",
        "cloudtrail:AddTags",
        "cloudtrail:RemoveTags"
      ]
      Resource = "*"
    },
    {
      Sid    = "ManageCloudWatchLogsFoundation"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:DescribeMetricFilters",
        "logs:DeleteMetricFilter",
        "logs:ListTagsForResource",
        "logs:PutMetricFilter",
        "logs:PutRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource"
      ]
      Resource = "*"
    },
    {
      Sid    = "ManageCloudWatchAlarmsFoundation"
      Effect = "Allow"
      Action = [
        "cloudwatch:DeleteAlarms",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListTagsForResource",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:TagResource",
        "cloudwatch:UntagResource"
      ]
      Resource = "*"
    },
    {
      Sid    = "ManageSNSFoundation"
      Effect = "Allow"
      Action = [
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetSubscriptionAttributes",
        "sns:GetTopicAttributes",
        "sns:ListSubscriptionsByTopic",
        "sns:ListTagsForResource",
        "sns:ListTopics",
        "sns:SetTopicAttributes",
        "sns:Subscribe",
        "sns:TagResource",
        "sns:Unsubscribe",
        "sns:UntagResource"
      ]
      Resource = "*"
    },
    {
      Sid    = "ManageGuardDutyFoundation"
      Effect = "Allow"
      Action = [
        "guardduty:CreateDetector",
        "guardduty:DeleteDetector",
        "guardduty:GetDetector",
        "guardduty:ListDetectors",
        "guardduty:UpdateDetector",
        "guardduty:TagResource",
        "guardduty:UntagResource",
        "guardduty:ListTagsForResource"
      ]
      Resource = "*"
    },
    {
      Sid      = "ManageBudgetsFoundation"
      Effect   = "Allow"
      Action   = "budgets:*"
      Resource = "*"
    },
    {
      Sid      = "ReadCallerIdentity"
      Effect   = "Allow"
      Action   = "sts:GetCallerIdentity"
      Resource = "*"
    },
    {
      Sid    = "CloudTrailLogsBucketPolicy"
      Effect = "Allow"
      Action = [
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy"
      ]
      Resource = "arn:aws:s3:::nestjs-hannibal-3-cloudtrail-logs"
    }
  ]

  hannibal_foundation_policy_core_sids = [
    "DenyFoundationBoundaryPolicyMutation",
    "DenyRemovingHannibalRoleBoundaries",
    "ReadHannibalIAMResources",
    "CreateOrSetApprovedHannibalRoleBoundaries",
    "ManageApprovedBoundaryHannibalRoles",
    "ManageApprovedBoundaryHannibalRolePolicies",
    "ManageApprovedHannibalPolicyAttachments",
    "ManageHannibalManagedPolicies",
    "ManageGitHubOIDCProvider",
    "PassCloudTrailCloudWatchLogsRole",
    "ListIAMFoundationResources",
    "ReadCallerIdentity"
  ]

  hannibal_foundation_policy_state_sids = [
    "TerraformFoundationStateBucketLocation",
    "TerraformFoundationStateBucketList",
    "TerraformFoundationStateObject",
    "TerraformFoundationStateLock"
  ]

  hannibal_foundation_policy_services_sids = [
    "ManageAthenaFoundation",
    "AthenaResultsBucket",
    "AthenaResultsObjects",
    "ManageFoundationS3Buckets",
    "ManageCloudTrailFoundation",
    "ManageCloudWatchLogsFoundation",
    "ManageCloudWatchAlarmsFoundation",
    "ManageSNSFoundation",
    "CloudTrailLogsBucketPolicy",
    "ManageGuardDutyFoundation",
    "ManageBudgetsFoundation"
  ]

  hannibal_foundation_policy_statements = [
    for statement in local.hannibal_foundation_all_policy_statements : statement
    if contains(local.hannibal_foundation_policy_core_sids, statement.Sid)
  ]

  hannibal_foundation_state_policy_statements = [
    for statement in local.hannibal_foundation_all_policy_statements : statement
    if contains(local.hannibal_foundation_policy_state_sids, statement.Sid)
  ]

  hannibal_foundation_services_policy_statements = [
    for statement in local.hannibal_foundation_all_policy_statements : statement
    if contains(local.hannibal_foundation_policy_services_sids, statement.Sid)
  ]
}

# --- 12. HannibalFoundationBoundary-Dev ---
# Foundation Role の最大権限を、foundation Terraform が扱うサービスに限定する。
resource "aws_iam_policy" "hannibal_foundation_boundary" {
  name        = "HannibalFoundationBoundary-Dev"
  description = "Permission boundary for terraform/foundation apply role"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.hannibal_foundation_boundary_statements
  })
}

resource "aws_iam_role" "hannibal_foundation_role" {
  name                 = "HannibalFoundationRole-Dev"
  permissions_boundary = aws_iam_policy.hannibal_foundation_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/hannibal"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-northeast-1"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "hannibal_foundation_policy" {
  name        = "HannibalFoundationPolicy-Dev"
  description = "Permissions for terraform/foundation apply only"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.hannibal_foundation_policy_statements
  })

  # Attach the split-out policies before narrowing this existing policy, so
  # foundation apply keeps backend state access throughout the transition.
  depends_on = [
    aws_iam_role_policy_attachment.hannibal_foundation_state_policy_attachment,
    aws_iam_role_policy_attachment.hannibal_foundation_services_policy_attachment
  ]
}

resource "aws_iam_policy" "hannibal_foundation_state_policy" {
  name        = "HannibalFoundationStatePolicy-Dev"
  description = "Foundation backend state permissions for terraform/foundation apply"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.hannibal_foundation_state_policy_statements
  })
}

resource "aws_iam_policy" "hannibal_foundation_services_policy" {
  name        = "HannibalFoundationServicesPolicy-Dev"
  description = "Managed service permissions for terraform/foundation apply"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.hannibal_foundation_services_policy_statements
  })
}

resource "aws_iam_role_policy_attachment" "hannibal_foundation_policy_attachment" {
  role       = aws_iam_role.hannibal_foundation_role.name
  policy_arn = aws_iam_policy.hannibal_foundation_policy.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_foundation_state_policy_attachment" {
  role       = aws_iam_role.hannibal_foundation_role.name
  policy_arn = aws_iam_policy.hannibal_foundation_state_policy.arn
}

resource "aws_iam_role_policy_attachment" "hannibal_foundation_services_policy_attachment" {
  role       = aws_iam_role.hannibal_foundation_role.name
  policy_arn = aws_iam_policy.hannibal_foundation_services_policy.arn
}

# --- 15. HannibalCloudTrailCloudWatchLogsRole-Dev ---
# CloudTrail が CloudWatch Logs に management events を配信するためのサービスロール。
resource "aws_iam_policy" "cloudtrail_cloudwatch_logs_boundary" {
  name        = "HannibalCloudTrailCloudWatchLogsBoundary-Dev"
  description = "Permission boundary for CloudTrail delivery to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailDeliveryToCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = local.cloudtrail_cloudwatch_log_stream_arn
      }
    ]
  })
}

resource "aws_iam_role" "cloudtrail_cloudwatch_logs_role" {
  name                 = "HannibalCloudTrailCloudWatchLogsRole-Dev"
  permissions_boundary = aws_iam_policy.cloudtrail_cloudwatch_logs_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch_logs_policy" {
  name = "CloudTrailCloudWatchLogsDelivery"
  role = aws_iam_role.cloudtrail_cloudwatch_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailCreateLogStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream"
        ]
        Resource = local.cloudtrail_cloudwatch_log_stream_arn
      },
      {
        Sid    = "AWSCloudTrailPutLogEvents"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = local.cloudtrail_cloudwatch_log_stream_arn
      }
    ]
  })
}
