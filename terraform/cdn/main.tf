data "terraform_remote_state" "service" {
  backend = "s3"

  config = {
    bucket = "nestjs-hannibal-3-terraform-state"
    key    = "service/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "s3" {
  source = "../modules/s3"

  s3_bucket_name              = var.s3_bucket_name
  frontend_build_path         = var.frontend_build_path
  cloudfront_distribution_arn = var.enable_cloudfront ? module.cloudfront.distribution_arn : null
}

module "cloudfront" {
  source = "../modules/cloudfront"

  project_name                   = var.project_name
  enable_cloudfront              = var.enable_cloudfront
  domain_name                    = var.domain_name
  s3_bucket_name                 = var.s3_bucket_name
  s3_bucket_regional_domain_name = module.s3.bucket_regional_domain_name
  api_origin_domain_name         = "api.${var.domain_name}"
  acm_certificate_arn_us_east_1  = var.acm_certificate_arn_us_east_1
  cloudfront_oac_id              = var.cloudfront_oac_id
  alb_origin_verify_header_name  = "X-Hannibal-Origin-Verify"
  alb_origin_verify_header_value = data.terraform_remote_state.service.outputs.alb_origin_verify_header_value
}

module "dns" {
  source = "../modules/dns"

  zone_name                 = var.domain_name
  domain_name               = var.domain_name
  hosted_zone_id            = var.hosted_zone_id
  cloudfront_domain_name    = var.enable_cloudfront ? module.cloudfront.distribution_domain_name : null
  cloudfront_hosted_zone_id = var.enable_cloudfront ? module.cloudfront.distribution_hosted_zone_id : null
  api_domain_name           = "api.${var.domain_name}"
  api_alb_dns_name          = data.terraform_remote_state.service.outputs.alb_dns_name
  api_alb_zone_id           = data.terraform_remote_state.service.outputs.alb_zone_id
}
