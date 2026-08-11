variable "monthly_limit" {
  description = "Monthly AWS budget ceiling in USD"
  type        = number
  default     = 50
}

variable "alert_email" {
  description = "Email address for budget alerts (in gitignored terraform.tfvars)"
  type        = string
}
