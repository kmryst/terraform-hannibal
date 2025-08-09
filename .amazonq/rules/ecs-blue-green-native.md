# ECS Native Blue/Green Deployment Rules (nestjs-hannibal-3)

## 概要
Amazon ECS built-in Blue/Green deployments (Released July 17, 2025)
TerraformでECS Native Blue/Green deploymentを実装するための実務ルール

## Schema Compatibility (Provider 6.8.0)
**AWS Provider**: 6.8.0 (tested)

**Supported**:
- `aws_ecs_service`: `deployment_controller { type = "ECS" }`
- `aws_ecs_service`: `deployment_configuration { bake_time_in_minutes = N }` (optional)
- ALB listener rule: `action.forward.target_group` with `weight`
- `lifecycle { ignore_changes = [action] }` on Priority 100 rules

**NOT supported in 6.8.0**:
- `advanced_configuration` (invalid; use standard `load_balancer` block only)
- `strategy = "BLUE_GREEN"` (invalid; do not use)
- `action.target_group_arn` (single direct forward; do not use)
- `lifecycle_hook` (not available in 6.8.0 schema)

ECS native Blue/Green is enabled with `deployment_controller { type = 'ECS' }` and managed cutovers occur via ALB Priority 100 rules using forward/weights; Terraform must not roll back those changes.

## 基本原則
- **ECS Native Blue/Green**: CodeDeploy不要
- **ALB Priority 100 rules**: 80 (prod) and 8080 (test)
- **Weight switching**: ECS flips 0/100→100/0
- **Terraform protection**: ignore_changes prevents rollback

## Minimum Working Example

```hcl
# ECS Service with Blue/Green
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  deployment_controller {
    type = "ECS"
  }
  
  deployment_configuration {
    bake_time_in_minutes = 5
  }
  
  # This project's default posture:
  # Recommended/prod-like: private subnets + assign_public_ip=false (default for this project)
  # Dev-simple (optional): public subnets + assign_public_ip=true (for quick checks only)
  network_configuration {
    subnets          = [aws_subnet.private.id]  # Use aws_subnet.public.id for dev-simple
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false  # true for dev-simple
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "app"
    container_port   = 3000
  }
}

# Target Groups
resource "aws_lb_target_group" "blue" {
  name        = "${var.project_name}-blue"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    path     = "/health"
    matcher  = "200"
    interval = 30
    timeout  = 5
  }
}

resource "aws_lb_target_group" "green" {
  name        = "${var.project_name}-green"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    path     = "/health"
    matcher  = "200"
    interval = 30
    timeout  = 5
  }
}

# Production Listener (80) - Priority 100 Rule
resource "aws_lb_listener_rule" "production" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  
  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.green.arn
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

# Test Listener (8080) - Priority 100 Rule
resource "aws_lb_listener_rule" "test" {
  listener_arn = aws_lb_listener.test.arn
  priority     = 100
  
  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = 0
      }
      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = 100
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

# Production Listener with safe default
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
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
```

## Tested Patterns

### Listener Rule Forward/Weights (Correct)
```hcl
# ✅ Correct - ECS can modify weights
action {
  type = "forward"
  forward {
    target_group {
      arn    = aws_lb_target_group.blue.arn
      weight = 100
    }
    target_group {
      arn    = aws_lb_target_group.green.arn
      weight = 0
    }
  }
}

# ❌ Invalid - Single target_group_arn
action {
  type             = "forward"
  target_group_arn = aws_lb_target_group.blue.arn
}
```

### IAM Policy (Least Privilege)
```hcl
resource "aws_iam_policy" "ecs_blue_green" {
  name = "ecs-blue-green-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### Monitoring Queries
*Linux/macOS shell commands shown; Windows users can translate to PowerShell.*

```bash
# Get ALB ARN by name
ALB_ARN=$(aws elbv2 describe-load-balancers --names my-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Get listener ARNs
PROD_LISTENER=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query 'Listeners[?Port==`80`].ListenerArn' --output text)
TEST_LISTENER=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query 'Listeners[?Port==`8080`].ListenerArn' --output text)

# Check Priority 100 rule weights (port 80)
aws elbv2 describe-rules \
  --listener-arn $PROD_LISTENER \
  --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].{Arn:TargetGroupArn,Weight:Weight}'

# Check Priority 100 rule weights (port 8080)
aws elbv2 describe-rules \
  --listener-arn $TEST_LISTENER \
  --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].{Arn:TargetGroupArn,Weight:Weight}'

# Verify weights sum to 100 (port 80)
aws elbv2 describe-rules \
  --listener-arn $PROD_LISTENER \
  --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].Weight | sum(@)'

# Verify weights sum to 100 (port 8080)
aws elbv2 describe-rules \
  --listener-arn $TEST_LISTENER \
  --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups[*].Weight | sum(@)'
```

## Acceptance Checklist (Provider 6.8.0)

1. **terraform validate** passes on provider 6.8.0
2. **terraform plan** shows no attempt to revert ECS changes to listener rule actions (ignore_changes working)
3. **During deployment**: Priority 100 rule weight flips from 0/100 to 100/0 (observed via describe-rules)
4. **After bake time**: ecs describe-services converges to single PRIMARY deployment
5. **Traffic routing**: Port 80 goes to new TG, 8080 remains for test side
6. **Priority 100 rule weights sum equals 100 on both 80 and 8080 at all times**
7. **aws ecs describe-services shows deployments converging to a single PRIMARY after bake time**:
   ```bash
   aws ecs describe-services --cluster my-cluster --services my-service --query 'services[0].deployments'
   ```
   Expected: PRIMARY only after bake time
8. **Simple rollback**: Set previous weights manually

## Limitations and Pitfalls (Provider 6.8.0)

**Avoid these mistakes**:
1. **Locking listener rule actions** in Terraform (causes rollbacks)
2. **Mismatched container_port/TG/health checks** (unhealthy targets)
3. **Using default_action to forward to blue** (risk of misroutes)
4. **Missing ignore_changes=[action]** (Terraform fights ECS)
5. **Do not change conditions/priority/listener_arn for the Priority 100 rules during routine applies; only weights should change at deployment time**
6. **If plan still shows diffs after manual/ECS weight changes, verify lifecycle { ignore_changes = [action] } is present on both Priority 100 rules and avoid unrelated rule edits that trigger re-creation**

**NOT supported in Provider 6.8.0**:
- `advanced_configuration` → Use standard `load_balancer` block only
- `strategy="BLUE_GREEN"` → Use `deployment_controller { type = "ECS" }`
- Direct `target_group_arn` in action → Use `action.forward.target_group` with weights
- `lifecycle_hook` → Not available in 6.8.0 schema

## Dev-Mode Cost Guidance

**After validation**:
1. Scale to zero: `desired_count = 0`
2. Close exposure: Update security group or stop listener
3. Weekly destroy: `terraform destroy` for full cleanup
4. Day-to-day: Use "stop" workflow instead of destroy

**Cost-sensitive pattern**:
```hcl
# Use locals for dev/prod networking and scaling
locals {
  is_dev = var.environment == "dev"
}

resource "aws_ecs_service" "api" {
  desired_count = local.is_dev ? 0 : var.desired_count
  
  network_configuration {
    # Project default: private subnets + assign_public_ip=false
    subnets          = local.is_dev ? [aws_subnet.public.id] : [aws_subnet.private.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = local.is_dev ? true : false
  }
  # ... rest of config
}
``` -var="environment=dev"
## Networking Posture Options

**Option A (dev-simple)**:
- Public subnets + `assign_public_ip = true`
- Direct internet access, simpler setup
- Use for development/testing only

**Option B (recommended/prod-like)**:
- Private subnets + `assign_public_ip = false`
- NAT Gateway for outbound, ALB for inbound
- **Default for nestjs-hannibal-3 project**

## Known Limitation (Provider 6.8.0)

**Issue**: Provider 6.8.0では`aws_ecs_service`に`deployment_configuration`ブロック（例: `bake_time_in_minutes`）を記述すると"Unexpected block"エラーが発生する場合がある。

**対応**: 当該ブロックはコメントアウト/削除して`terraform validate/plan`を通す。ECSネイティブB/Gの挙動自体は、ALBのPriority 100ルール（forward/weights）と`ignore_changes=[action]`により運用可能。

## Current Recommended Operation (until provider adds fields)

- デプロイ/カナリアは`modify-rule`でweightを10/90→30/70→…→100/0に段階変更
- Priority 100ルールの両方に`lifecycle { ignore_changes = [action] }`を設定し、TerraformがECS/手動変更を巻き戻さないようにする

## Verification and Acceptance (unchanged)

- 80/8080のPriority 100の`ForwardConfig.TargetGroups[*].Weight`を`describe-rules`で確認し、weights合計=100を常に満たすこと
- `aws ecs describe-services --cluster <cluster> --services <service> --query 'services.deployments'`で、ベイク後にPRIMARYのみへ収束することを確認（ベイク時間は現状Provider 6.8.0では明示設定せず、ECSのデフォルト挙動に委ねる）

## Upgrade Path

- Terraform Registry（aws_ecs_service）の公式スキーマにBlue/Green用属性（bake_time/lifecycle hooks等）が掲載・サポートされたら、正確な属性名で`deployment_configuration`を再導入する
- 本節の「Known limitation」を削除/更新し、ルールの"Supported"側へ移す

## Quick Deploy

```bash
# Standard ECS update triggers Blue/Green
aws ecs update-service \
  --cluster my-cluster \
  --service my-service \
  --task-definition my-task:123
```

---
**Minimal, actionable ECS Native Blue/Green with Terraform**
**Provider 6.8.0 validated • No CodeDeploy required**