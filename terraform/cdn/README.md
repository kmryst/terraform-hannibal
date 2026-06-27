# terraform/cdn

CloudFront、S3 frontend bucket 参照、Route53 record など、公開配信経路を管理する root module です。

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.8.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cloudfront"></a> [cloudfront](#module\_cloudfront) | ../modules/cloudfront | n/a |
| <a name="module_dns"></a> [dns](#module\_dns) | ../modules/dns | n/a |
| <a name="module_s3"></a> [s3](#module\_s3) | ../modules/s3 | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [terraform_remote_state.service](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acm_certificate_arn_us_east_1"></a> [acm\_certificate\_arn\_us\_east\_1](#input\_acm\_certificate\_arn\_us\_east\_1) | ACM certificate ARN in us-east-1 for CloudFront | `string` | n/a | yes |
| <a name="input_cloudfront_oac_id"></a> [cloudfront\_oac\_id](#input\_cloudfront\_oac\_id) | CloudFront Origin Access Control ID | `string` | `"E1EA19Y8SLU52D"` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for the application | `string` | `"hamilcar-hannibal.click"` | no |
| <a name="input_enable_cloudfront"></a> [enable\_cloudfront](#input\_enable\_cloudfront) | Whether to enable CloudFront distribution | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g. dev, staging, prod) | `string` | `"dev"` | no |
| <a name="input_frontend_build_path"></a> [frontend\_build\_path](#input\_frontend\_build\_path) | Path to the frontend build directory | `string` | `"../../../client/dist"` | no |
| <a name="input_hosted_zone_id"></a> [hosted\_zone\_id](#input\_hosted\_zone\_id) | Route53 hosted zone ID | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name used for resource naming | `string` | `"nestjs-hannibal-3"` | no |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | S3 bucket name for frontend assets | `string` | `"nestjs-hannibal-3-frontend"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cloudfront_distribution_arn"></a> [cloudfront\_distribution\_arn](#output\_cloudfront\_distribution\_arn) | CloudFront distribution ARN |
| <a name="output_cloudfront_distribution_domain_name"></a> [cloudfront\_distribution\_domain\_name](#output\_cloudfront\_distribution\_domain\_name) | CloudFront distribution domain name |
| <a name="output_cloudfront_distribution_id"></a> [cloudfront\_distribution\_id](#output\_cloudfront\_distribution\_id) | CloudFront distribution ID (extracted from ARN) |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | S3 bucket ID |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | S3 bucket name |
<!-- END_TF_DOCS -->
