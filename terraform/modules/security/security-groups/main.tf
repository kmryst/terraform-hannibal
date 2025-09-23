# Security Groups for Three-tier Architecture (Least Privilege)

# --- ALB Security Group ---
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB security group for three-tier architecture"
  vpc_id      = var.vpc_id
  
  # Production Listener (Port 80)
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Test Listener for Blue/Green (Port 8080)
  ingress {
    description = "Test HTTP from internet"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # HTTPS Listener (Port 443)
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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