# --- AWS Professional Environment Configuration ---
locals {
  # 環境別リソース最適化（Netflix/Airbnb/Spotify標準パターン）
  enable_multi_az        = var.environment != "dev"
  enable_backup          = var.environment != "dev"
  backup_retention_days  = var.environment == "prod" ? 7 : 0
  publicly_accessible    = var.environment == "dev"
  deletion_protection    = var.environment == "prod"
}

# --- RDS Subnet Group ---
resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.data_subnet_ids
  
  tags = {
    Name        = "${var.project_name} DB subnet group"
    project     = var.project_name
    environment = var.environment
  }
}

# RDS Security Group moved to security_groups.tf

# --- RDS PostgreSQL Instance ---
resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [var.rds_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  
  iam_database_authentication_enabled = true
  
  # AWS Professional環境別設定（Netflix/Airbnb/Spotify標準）
  backup_retention_period = local.backup_retention_days
  multi_az               = local.enable_multi_az
  publicly_accessible    = false
  
  # 本番環境のみ有効
  backup_window      = local.enable_backup ? "03:00-04:00" : null
  maintenance_window = local.enable_backup ? "sun:04:00-sun:05:00" : null
  
  skip_final_snapshot = true
  deletion_protection = local.deletion_protection
  
  tags = {
    Name = "${var.project_name}-postgres"
  }
}