variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "pr_number" {
  description = "GitHub pull request number used to identify the preview environment"
  type        = number

  validation {
    condition = (
      var.pr_number >= 1 &&
      var.pr_number <= 99999999999 &&
      floor(var.pr_number) == var.pr_number
    )
    error_message = "pr_number must be a positive integer with at most 11 digits."
  }
}
