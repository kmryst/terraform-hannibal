module "vpc" {
  source = "../modules/vpc"

  project_name                            = var.project_name
  environment                             = var.environment
  container_port                          = var.container_port
  cloudfront_origin_facing_prefix_list_id = var.cloudfront_origin_facing_prefix_list_id
}
