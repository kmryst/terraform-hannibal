# terraform/service

ECS、ALB、CodeDeploy、monitoring など、アプリケーション実行基盤を管理する root module です。

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.8.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_codedeploy"></a> [codedeploy](#module\_codedeploy) | ../modules/codedeploy | n/a |
| <a name="module_ecs"></a> [ecs](#module\_ecs) | ../modules/ecs | n/a |
| <a name="module_load_balancer"></a> [load\_balancer](#module\_load\_balancer) | ../modules/load-balancer | n/a |
| <a name="module_monitoring"></a> [monitoring](#module\_monitoring) | ../modules/monitoring | n/a |
| <a name="module_synthetics_canary"></a> [synthetics\_canary](#module\_synthetics\_canary) | ../modules/synthetics | n/a |

## Resources

| Name | Type |
|------|------|
| [random_password.alb_origin_verify_header](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [terraform_remote_state.database](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.network](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_certificate_arn"></a> [alb\_certificate\_arn](#input\_alb\_certificate\_arn) | ACM certificate ARN for HTTPS listener | `string` | n/a | yes |
| <a name="input_alb_origin_secret_rotation_version"></a> [alb\_origin\_secret\_rotation\_version](#input\_alb\_origin\_secret\_rotation\_version) | Version key for rotating the ALB origin verify header secret | `string` | `"v1"` | no |
| <a name="input_alert_email"></a> [alert\_email](#input\_alert\_email) | Email address for CloudWatch alarm notifications | `string` | `"gatsbykenji@gmail.com"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"ap-northeast-1"` | no |
| <a name="input_client_url_for_cors"></a> [client\_url\_for\_cors](#input\_client\_url\_for\_cors) | Client URL for CORS configuration | `string` | `""` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Container port for the application | `number` | `3000` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | CPU units for the ECS task | `number` | `256` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Database name | `string` | `"nestjs_hannibal_db"` | no |
| <a name="input_deployment_type"></a> [deployment\_type](#input\_deployment\_type) | CodeDeploy deployment type (canary or linear) | `string` | `"canary"` | no |
| <a name="input_desired_task_count"></a> [desired\_task\_count](#input\_desired\_task\_count) | Desired number of ECS tasks | `number` | `1` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Public domain name. terraform/cdn の同名変数と値を揃える(service は cdn より前に apply されるため remote\_state 参照ができない) | `string` | `"hamilcar-hannibal.click"` | no |
| <a name="input_ecr_repository_url"></a> [ecr\_repository\_url](#input\_ecr\_repository\_url) | ECR repository URL for the container image | `string` | n/a | yes |
| <a name="input_enable_synthetics_canary"></a> [enable\_synthetics\_canary](#input\_enable\_synthetics\_canary) | Synthetics canaryを作成するかどうか。dev環境のオンデマンド運用(ADR-0008)に合わせてtrue/falseを切り替える | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g. dev, staging, prod) | `string` | `"dev"` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Health check path for target groups | `string` | `"/health"` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory (MiB) for the ECS task | `number` | `512` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name used for resource naming | `string` | `"nestjs-hannibal-3"` | no |
| <a name="input_synthetics_canary_name"></a> [synthetics\_canary\_name](#input\_synthetics\_canary\_name) | Synthetics canaryの名前(CloudWatch Syntheticsの制約で21文字以内) | `string` | `"hannibal-canary"` | no |
| <a name="input_synthetics_graphql_query"></a> [synthetics\_graphql\_query](#input\_synthetics\_graphql\_query) | canaryが実行するGraphQL読み取り専用クエリ(src/graphql/schema/map.graphqlのcapitalCitiesを使用) | `string` | `"query { capitalCities { type features { type properties { name } } } }"` | no |
| <a name="input_synthetics_schedule_expression"></a> [synthetics\_schedule\_expression](#input\_synthetics\_schedule\_expression) | Synthetics canaryの実行間隔 | `string` | `"rate(5 minutes)"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | ALB DNS name |
| <a name="output_alb_origin_verify_header_value"></a> [alb\_origin\_verify\_header\_value](#output\_alb\_origin\_verify\_header\_value) | ALB origin verify header value for CloudFront |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | ALB hosted zone ID |
| <a name="output_blue_target_group_name"></a> [blue\_target\_group\_name](#output\_blue\_target\_group\_name) | Blue target group name |
| <a name="output_codedeploy_application_name"></a> [codedeploy\_application\_name](#output\_codedeploy\_application\_name) | CodeDeploy application name |
| <a name="output_codedeploy_deployment_group_name"></a> [codedeploy\_deployment\_group\_name](#output\_codedeploy\_deployment\_group\_name) | CodeDeploy deployment group name |
| <a name="output_codedeploy_s3_bucket"></a> [codedeploy\_s3\_bucket](#output\_codedeploy\_s3\_bucket) | S3 bucket for CodeDeploy artifacts |
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | CloudWatch dashboard URL |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | ECS cluster name |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | ECS service name |
| <a name="output_green_target_group_name"></a> [green\_target\_group\_name](#output\_green\_target\_group\_name) | Green target group name |
| <a name="output_slo_error_rate_fast_burn_alarm_arn"></a> [slo\_error\_rate\_fast\_burn\_alarm\_arn](#output\_slo\_error\_rate\_fast\_burn\_alarm\_arn) | ARN of the SLO error-rate fast-burn alarm (consumed by terraform/observability as an AWS FIS stop condition, Issue #458) |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | SNS topic ARN for alarm notifications |
| <a name="output_synthetics_availability_alarm_name"></a> [synthetics\_availability\_alarm\_name](#output\_synthetics\_availability\_alarm\_name) | Name of the Synthetics canary time-based availability alarm (ADR-0030, Issue #467). null when disabled |
| <a name="output_synthetics_canary_arn"></a> [synthetics\_canary\_arn](#output\_synthetics\_canary\_arn) | ARN of the Synthetics user-journey canary. null when disabled |
| <a name="output_synthetics_canary_artifacts_bucket_name"></a> [synthetics\_canary\_artifacts\_bucket\_name](#output\_synthetics\_canary\_artifacts\_bucket\_name) | S3 bucket name storing Synthetics canary run artifacts. null when disabled |
| <a name="output_synthetics_canary_name"></a> [synthetics\_canary\_name](#output\_synthetics\_canary\_name) | Name of the Synthetics user-journey canary (ADR-0030, Issue #465). null when disabled |
<!-- END_TF_DOCS -->
