
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
      - arn:aws:elasticloadbalancing:ap-northeast-1:258632448142:targetgroup/nestjs-hannibal-3-blue-tg/abc123
  testTrafficRoute:
    listenerArn: arn:aws:elasticloadbalancing:ap-northeast-1:258632448142:listener/app/nestjs-hannibal-3-alb/8080
    targetGroupArns:
      - arn:aws:elasticloadbalancing:ap-northeast-1:258632448142:targetgroup/nestjs-hannibal-3-green-tg/def456

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
        - ecs:CreateTaskSet
        - ecs:UpdateServicePrimaryTaskSet
        - ecs:DeleteTaskSet
      Resource:
        - arn:aws:ecs:ap-northeast-1:258632448142:service/nestjs-hannibal-3-cluster/nestjs-hannibal-3-api-service
        - arn:aws:ecs:ap-northeast-1:258632448142:task-definition/nestjs-hannibal-3-api-task*
    - Effect: Allow
      Action:
        - elasticloadbalancing:ModifyListener
        - elasticloadbalancing:DescribeListeners
        - elasticloadbalancing:DescribeTargetGroups
        - elasticloadbalancing:DescribeRules
        - elasticloadbalancing:ModifyRule
      Resource: "*"
    - Effect: Allow
      Action:
        - iam:PassRole
      Resource: arn:aws:iam::258632448142:role/HannibalCICDRole-Dev
    - Effect: Allow
      Action:
        - cloudwatch:DescribeAlarms
      Resource: "*"
    - Effect: Allow
      Action:
        - sns:Publish
      Resource: arn:aws:sns:ap-northeast-1:258632448142:nestjs-hannibal-3-alerts

# Terraform 実装設定
terraform:
  load_balancer_info:
    # ECS Blue/Green デプロイメント用の正しい構文
    target_group_pair_info:
      # 本番トラフィック用リスナー（ポート80）
      prod_traffic_route:
        listener_arns:
          - arn:aws:elasticloadbalancing:ap-northeast-1:258632448142:listener/app/nestjs-hannibal-3-alb/80
      # テストトラフィック用リスナー（ポート8080）
      test_traffic_route:
        listener_arns:
          - arn:aws:elasticloadbalancing:ap-northeast-1:258632448142:listener/app/nestjs-hannibal-3-alb/8080
      # Blue/Green ターゲットグループ
      target_group:
        - name: nestjs-hannibal-3-blue-tg
        - name: nestjs-hannibal-3-green-tg

  blue_green_deployment_config:
    # デプロイ準備オプション
    deployment_ready_option:
      action_on_timeout: "STOP_DEPLOYMENT"
      wait_time_in_minutes: 5
    # Blue環境の終了設定
    terminate_blue_instances_on_deployment_success:
      action: "TERMINATE"
      termination_wait_time_in_minutes: 5
    # グリーン環境プロビジョニング設定
    green_fleet_provisioning_option:
      action: "COPY_AUTO_SCALING_GROUP"

  deployment_style:
    deployment_type: "BLUE_GREEN"
    deployment_option: "WITH_TRAFFIC_CONTROL"

  ecs_service:
    cluster_name: "nestjs-hannibal-3-cluster"
    service_name: "nestjs-hannibal-3-api-service"

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
