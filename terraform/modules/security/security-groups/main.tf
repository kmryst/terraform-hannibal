# Security Groups for Three-tier Architecture (Least Privilege)

# --- ALB Security Group ---
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB security group for three-tier architecture"
  vpc_id      = var.vpc_id

  # CloudFront managed prefix list has weight 55, so the ALB listener range is kept
  # in one rule to stay within the default security group rule quota.
  ingress {
    description     = "ALB listeners from CloudFront origin-facing addresses"
    from_port       = 80
    to_port         = 8080
    protocol        = "tcp"
    prefix_list_ids = [var.cloudfront_origin_facing_prefix_list_id]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    project     = var.project_name
    environment = var.environment
  }
}

# --- ECS Security Group ---
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "ECS security group for three-tier architecture"
  vpc_id      = var.vpc_id

  # Ingress from ALB only - container_portを動的に許可
  ingress {
    description     = "From ALB to container port"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow all outbound traffic (for RDS, ECR, CloudWatch, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ecs-sg"
    project     = var.project_name
    environment = var.environment
  }
}

# --- RDS Security Group ---
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS security group for three-tier architecture"
  vpc_id      = var.vpc_id

  # Ingress from ECS only
  ingress {
    description     = "From ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    project     = var.project_name
    environment = var.environment
  }
}
