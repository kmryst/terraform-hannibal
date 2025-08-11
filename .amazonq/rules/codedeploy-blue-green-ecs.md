# CodeDeploy Blue/Green for ECS Rules

# q-developer-rules.yml
version: 1.0
description: >
  NestJS Hannibal 3 の CodeDeploy Blue/Green デプロイメントを自動化するためのルール。

# デプロイ対象の ECS Service 定義
targets:
  - name: api-service
    type: ECS
    cluster: nestjs-hannibal-3-cluster
    service: nestjs-hannibal-3-api-service
    taskDefinition: nestjs-hannibal-3-api-task

# Blue/Green デプロイ設定
blueGreen:
  deploymentConfigName: CodeDeployDefault.ECSAllAtOnce
  # Bake time を指定したい場合は下記を有効化
  # deploymentConfigName: CustomConfigWithBakeTime
  termination:
    waitTimeInMinutes: 5
  prodTrafficRoute:
    listenerArn: arn:aws:elasticloadbalancing:ap-northeast-1:258632448142:listener/app/nestjs-hannibal-3-alb/80
    targetGroupArns:
      - arn:aws:elasticloadbalancing:ap-northeast-1:258632448142:targetgroup/nestjs-hannibal-3-blue-tg/…
  testTrafficRoute:
    listenerArn: arn:aws:elasticloadbalancing:ap-northeast-1:258632448142:listener/app/nestjs-hannibal-3-alb/8080
    targetGroupArns:
      - arn:aws:elasticloadbalancing:ap-northeast-1:258632448142:targetgroup/nestjs-hannibal-3-green-tg/…

# デプロイフェーズごとのコマンド
phases:
  BeforeInstall:
    - echo "準備フェーズ：新しいタスク定義の登録を準備"
  AfterInstall:
    - aws ecs update-service \
        --cluster nestjs-hannibal-3-cluster \
        --service nestjs-hannibal-3-api-service \
        --task-definition $CODEDEPLOY_NEW_TASK_DEF_ARN
  AfterAllowTestTraffic:
    - echo "テストトラフィックが許可されました。動作検証を実施"
  BeforeAllowTraffic:
    - echo "プロダクショントラフィック切り替え前アクション"
  AfterAllowTraffic:
    - echo "プロダクショントラフィックへ切り替え完了"

# IAM 権限定義（最小限）
iam:
  assumeRole:
    RoleArn: arn:aws:iam::258632448142:role/HannibalCICDRole-Dev
  policies:
    - Effect: Allow
      Action:
        - codedeploy:CreateDeployment
        - codedeploy:GetDeployment
        - codedeploy:RegisterApplicationRevision
        - codedeploy:GetDeploymentConfig
      Resource: "*"
    - Effect: Allow
      Action:
        - ecs:UpdateService
        - ecs:DescribeServices
        - ecs:RegisterTaskDefinition
      Resource:
        - arn:aws:ecs:ap-northeast-1:258632448142:service/nestjs-hannibal-3-cluster/nestjs-hannibal-3-api-service
        - arn:aws:ecs:ap-northeast-1:258632448142:task-definition/nestjs-hannibal-3-api-task*
    - Effect: Allow
      Action:
        - elasticloadbalancing:ModifyListener
        - elasticloadbalancing:DescribeListeners
        - elasticloadbalancing:DescribeTargetGroups
      Resource: "*"
    - Effect: Allow
      Action:
        - iam:PassRole
      Resource: arn:aws:iam::258632448142:role/HannibalCICDRole-Dev

# モニタリング & ログ
monitoring:
  successThreshold: 1
  failureThreshold: 1
  alarms:
    - name: ecs-green-health-check-failed
      namespace: AWS/ECS
      metric: HealthyHostCount
      threshold: 1
      comparisonOperator: LessThanThreshold
      evaluationPeriods: 2
      dimensions:
        ClusterName: nestjs-hannibal-3-cluster
        ServiceName: nestjs-hannibal-3-api-service
  logs:
    group: /aws/codedeploy/nestjs-hannibal-3
    stream: blue-green-deploy

# 通知設定
notifications:
  onSuccess:
    - sns: arn:aws:sns:ap-northeast-1:258632448142:nestjs-hannibal-3-alerts
  onFailure:
    - sns: arn:aws:sns:ap-northeast-1:258632448142:nestjs-hannibal-3-alerts
