# terraform/environments/dev/frontend.tf
# Frontend モジュール統合設定

locals {
  api_domain_name               = "api.${var.domain_name}"
  alb_origin_verify_header_name = "X-Hannibal-Origin-Verify"
}

resource "random_password" "alb_origin_verify_header" {
  length  = 48
  special = false

  keepers = {
    rotation_version = var.alb_origin_secret_rotation_version
  }
}

# --- CDN Pillar: S3 Static Hosting ---
module "s3_frontend" {
  source = "../../modules/storage/s3"

  s3_bucket_name              = var.s3_bucket_name
  frontend_build_path         = var.frontend_build_path
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
}

# --- CDN Pillar: CloudFront Distribution ---
module "cloudfront" {
  source = "../../modules/cdn/cloudfront"

  project_name                   = var.project_name
  enable_cloudfront              = var.enable_cloudfront
  domain_name                    = var.domain_name
  s3_bucket_name                 = var.s3_bucket_name
  s3_bucket_regional_domain_name = module.s3_frontend.bucket_regional_domain_name
  api_origin_domain_name         = local.api_domain_name
  acm_certificate_arn_us_east_1  = var.acm_certificate_arn_us_east_1
  cloudfront_oac_id              = var.cloudfront_oac_id
  alb_origin_verify_header_name  = local.alb_origin_verify_header_name
  alb_origin_verify_header_value = random_password.alb_origin_verify_header.result
}

# --- Reliability Pillar: DNS ---
module "dns_frontend" {
  source = "../../modules/networking/dns"

  zone_name                 = var.domain_name
  domain_name               = var.domain_name
  hosted_zone_id            = var.hosted_zone_id
  cloudfront_domain_name    = module.cloudfront.distribution_domain_name
  cloudfront_hosted_zone_id = module.cloudfront.distribution_hosted_zone_id
  api_domain_name           = local.api_domain_name
  api_alb_dns_name          = module.load_balancer.alb_dns_name
  api_alb_zone_id           = module.load_balancer.alb_zone_id
}
