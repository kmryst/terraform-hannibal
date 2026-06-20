resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB security group for three-tier architecture"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "ALB listeners from CloudFront origin-facing addresses"
    from_port       = 80
    to_port         = 8080
    protocol        = "tcp"
    prefix_list_ids = [var.cloudfront_origin_facing_prefix_list_id]
  }

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

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "ECS security group for three-tier architecture"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ALB to container port"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

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

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS security group for three-tier architecture"
  vpc_id      = aws_vpc.main.id

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
