locals {
  project_name     = "nestjs-hannibal-3"
  environment_type = "preview"
  environment_name = "${local.environment_type}-pr-${var.pr_number}"
  resource_prefix  = "hannibal-pr-${var.pr_number}"
}
