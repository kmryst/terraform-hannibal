data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "nestjs-hannibal-3-terraform-state"
    key    = "network/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "rds" {
  source = "../modules/rds"

  project_name                = var.project_name
  environment                 = var.environment
  db_instance_class           = var.db_instance_class
  db_allocated_storage        = var.db_allocated_storage
  db_engine_version           = var.db_engine_version
  db_name                     = var.db_name
  db_username                 = var.db_username
  db_password                 = var.db_password
  manage_master_user_password = var.manage_master_user_password
  data_subnet_ids             = data.terraform_remote_state.network.outputs.data_subnet_ids
  rds_security_group_id       = data.terraform_remote_state.network.outputs.rds_security_group_id
}
