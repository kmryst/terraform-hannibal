variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "canary_name" {
  description = "Name of the Synthetics canary (max 21 chars, lowercase alphanumeric and hyphens)"
  type        = string

  validation {
    condition     = length(var.canary_name) <= 21 && can(regex("^[a-z0-9-]+$", var.canary_name))
    error_message = "canary_name must be at most 21 characters and contain only lowercase letters, digits, and hyphens (CloudWatch Synthetics naming constraint)."
  }
}

variable "runtime_version" {
  description = "CloudWatch Synthetics runtime version(Node.js + Puppeteer)。https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Library_nodejs_puppeteer.html を参照"
  type        = string
  default     = "syn-nodejs-puppeteer-16.1" # 2026-07時点の最新runtime(Node.js 22.x)
}

variable "schedule_expression" {
  description = "CloudWatch Synthetics canary schedule expression (rate or cron)"
  type        = string
  default     = "rate(5 minutes)"
}

variable "canary_timeout_in_seconds" {
  description = "Timeout for a single canary run"
  type        = number
  default     = 30
}

variable "frontend_url" {
  description = "Frontend URL served via CloudFront (user journey step 1: frontend delivery)"
  type        = string
}

variable "api_health_url" {
  description = "Backend health check URL requested via CloudFront (user journey step 2)"
  type        = string
}

variable "api_graphql_url" {
  description = "Backend GraphQL endpoint URL requested via CloudFront (user journey step 3: read-only query)"
  type        = string
}

variable "graphql_query" {
  description = "GraphQL read-only query body used to verify the backend during canary runs"
  type        = string
  default     = "query { capitalCities { type features { type properties { name } } } }"
}

variable "origin_verify_header_name" {
  description = "Name of the ALB origin-verify header required to bypass the 403 deny rule (see terraform/modules/load-balancer)"
  type        = string
}

variable "origin_verify_secret_arn" {
  description = "Secrets Manager secret ARN that stores the ALB origin-verify header value. The canary execution role is granted GetSecretValue scoped to this ARN only"
  type        = string
}

variable "tags" {
  description = "Additional tags for canary-related resources"
  type        = map(string)
  default     = {}
}
