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

# --- ALB Listener (HTTP Redirect) ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_listener_port
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# --- ALB Listener (Production HTTPS) ---
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.alb_certificate_arn

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
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.alb_certificate_arn

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
resource "aws_lb_listener_rule" "production_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type = "forward"
    forward {
      target_group {
        arn    = var.blue_target_group_arn
        weight = 100 # 初期Blue 100%
      }
      target_group {
        arn    = var.green_target_group_arn
        weight = 0 # 初期Green 0%
      }
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  condition {
    http_header {
      http_header_name = var.alb_origin_verify_header_name
      values           = [var.alb_origin_verify_header_value]
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

  condition {
    http_header {
      http_header_name = var.alb_origin_verify_header_name
      values           = [var.alb_origin_verify_header_value]
    }
  }

  lifecycle {
    ignore_changes = [action]
  }
}

resource "aws_lb_listener_rule" "production_https_deny_without_origin_header" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Access denied"
      status_code  = "403"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_listener_rule" "test_deny_without_origin_header" {
  listener_arn = aws_lb_listener.test.arn
  priority     = 200

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Access denied"
      status_code  = "403"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
