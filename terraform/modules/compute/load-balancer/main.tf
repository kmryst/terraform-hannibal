# --- ALB (Application Load Balancer) ---
resource "aws_lb" "main" {
  name                       = "${var.project_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = false
  drop_invalid_header_fields = true
}

# Blue/Green Target Groups are defined in codedeploy.tf

# --- ALB Listener (Production HTTP) ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_listener_port
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# --- ALB Listener (Production HTTPS) ---
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "arn:aws:acm:ap-northeast-1:258632448142:certificate/9ab350e8-1748-4e17-aa89-9db7c889b146"
  
  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = var.blue_target_group_arn
        weight = 100
      }
    }
  }
}

# --- ALB Test Listener (Blue/Green Dark Canary) ---
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"
  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = var.blue_target_group_arn
        weight = 100
      }
    }
  }
}

# --- ALB Listener Rules for Blue/Green ---
# 初期状態でBlue環境に100%トラフィックを送信、CodeDeployの動的切替と競合しない構成
resource "aws_lb_listener_rule" "production_http" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  
  action {
    type = "forward"
    forward {
      target_group {
        arn    = var.blue_target_group_arn
        weight = 100  # 初期Blue 100%
      }
      target_group {
        arn    = var.green_target_group_arn
        weight = 0    # 初期Green 0%
      }
    }
  }
  
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
  
  lifecycle {
    # CodeDeployによる動的切替を許容
    ignore_changes = [action]
  }
}

resource "aws_lb_listener_rule" "production_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100
  
  action {
    type = "forward"
    forward {
      target_group {
        arn    = var.blue_target_group_arn
        weight = 100  # 初期Blue 100%
      }
      target_group {
        arn    = var.green_target_group_arn
        weight = 0    # 初期Green 0%
      }
    }
  }
  
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
  
  lifecycle {
    # CodeDeployによる動的切替を許容
    ignore_changes = [action]
  }
}

resource "aws_lb_listener_rule" "test" {
  listener_arn = aws_lb_listener.test.arn
  priority     = 100
  
  action {
    type = "forward"
    forward {
      target_group {
        arn    = var.blue_target_group_arn
        weight = 100
      }
      target_group {
        arn    = var.green_target_group_arn
        weight = 0
      }
    }
  }
  
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
  
  lifecycle {
    ignore_changes = [action]
  }
}