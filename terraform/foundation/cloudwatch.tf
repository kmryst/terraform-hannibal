# CloudTrail real-time security monitoring

locals {
  cloudtrail_cloudwatch_log_group_name = "/aws/cloudtrail/nestjs-hannibal-3"
  cloudtrail_cloudwatch_log_group_arn  = "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:${local.cloudtrail_cloudwatch_log_group_name}"
  cloudtrail_cloudwatch_log_stream_arn = "${local.cloudtrail_cloudwatch_log_group_arn}:log-stream:${data.aws_caller_identity.current.account_id}_CloudTrail_*"
  cloudtrail_security_metric_namespace = "Hannibal/CloudTrailSecurity"

  cloudtrail_security_alerts = {
    root_account_usage = {
      filter_name       = "root-account-usage"
      metric_name       = "RootAccountUsageCount"
      alarm_name        = "nestjs-hannibal-3-cloudtrail-root-account-usage"
      alarm_description = "Root account activity was detected in CloudTrail."
      pattern           = "{ ($.userIdentity.type = \"Root\") && ($.userIdentity.invokedBy NOT EXISTS) && ($.eventType != \"AwsServiceEvent\") }"
    }
    iam_policy_change = {
      filter_name       = "iam-policy-change"
      metric_name       = "IAMPolicyChangeCount"
      alarm_name        = "nestjs-hannibal-3-cloudtrail-iam-policy-change"
      alarm_description = "IAM policy or policy attachment activity was detected in CloudTrail."
      pattern           = "{ ($.eventName = \"DeleteGroupPolicy\") || ($.eventName = \"DeleteRolePolicy\") || ($.eventName = \"DeleteUserPolicy\") || ($.eventName = \"PutGroupPolicy\") || ($.eventName = \"PutRolePolicy\") || ($.eventName = \"PutUserPolicy\") || ($.eventName = \"CreatePolicy\") || ($.eventName = \"DeletePolicy\") || ($.eventName = \"CreatePolicyVersion\") || ($.eventName = \"DeletePolicyVersion\") || ($.eventName = \"AttachRolePolicy\") || ($.eventName = \"DetachRolePolicy\") || ($.eventName = \"AttachUserPolicy\") || ($.eventName = \"DetachUserPolicy\") || ($.eventName = \"AttachGroupPolicy\") || ($.eventName = \"DetachGroupPolicy\") }"
    }
    cloudtrail_configuration_change = {
      filter_name       = "cloudtrail-configuration-change"
      metric_name       = "CloudTrailConfigurationChangeCount"
      alarm_name        = "nestjs-hannibal-3-cloudtrail-configuration-change"
      alarm_description = "CloudTrail configuration activity was detected in CloudTrail."
      pattern           = "{ ($.eventName = \"CreateTrail\") || ($.eventName = \"UpdateTrail\") || ($.eventName = \"DeleteTrail\") || ($.eventName = \"StartLogging\") || ($.eventName = \"StopLogging\") || ($.eventName = \"PutEventSelectors\") }"
    }
    console_signin_without_mfa = {
      filter_name       = "console-signin-without-mfa"
      metric_name       = "ConsoleSigninWithoutMfaCount"
      alarm_name        = "nestjs-hannibal-3-cloudtrail-console-signin-without-mfa"
      alarm_description = "AWS Management Console sign-in without MFA was detected in CloudTrail."
      pattern           = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") }"
    }
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = local.cloudtrail_cloudwatch_log_group_name
  retention_in_days = 30

  tags = {
    Project     = "nestjs-hannibal-3"
    Environment = "Dev"
    ManagedBy   = "terraform/foundation"
    Purpose     = "cloudtrail-security-monitoring"
  }

  depends_on = [aws_iam_role_policy_attachment.hannibal_foundation_services_policy_attachment]
}

resource "aws_sns_topic" "cloudtrail_security_alerts" {
  name = "nestjs-hannibal-3-security-alerts"

  tags = {
    Project     = "nestjs-hannibal-3"
    Environment = "Dev"
    ManagedBy   = "terraform/foundation"
    Purpose     = "cloudtrail-security-alerts"
  }

  depends_on = [aws_iam_role_policy_attachment.hannibal_foundation_services_policy_attachment]
}

resource "aws_sns_topic_subscription" "cloudtrail_security_email" {
  topic_arn = aws_sns_topic.cloudtrail_security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_metric_filter" "cloudtrail_security" {
  for_each = local.cloudtrail_security_alerts

  name           = each.value.filter_name
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = each.value.pattern

  metric_transformation {
    name      = each.value.metric_name
    namespace = local.cloudtrail_security_metric_namespace
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudtrail_security" {
  for_each = local.cloudtrail_security_alerts

  alarm_name          = each.value.alarm_name
  alarm_description   = each.value.alarm_description
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = each.value.metric_name
  namespace           = local.cloudtrail_security_metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.cloudtrail_security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = {
    Project     = "nestjs-hannibal-3"
    Environment = "Dev"
    ManagedBy   = "terraform/foundation"
    Purpose     = "cloudtrail-security-monitoring"
  }

  depends_on = [aws_cloudwatch_log_metric_filter.cloudtrail_security]
}
