locals {
  tags = { Project = "tarmac" }
}

provider "aws" {
  region  = "ap-south-1"
  profile = "cloudsentry"
}

# Budgets is a global service; pin its provider to us-east-1.
provider "aws" {
  alias   = "budgets"
  region  = "us-east-1"
  profile = "cloudsentry"
}

resource "aws_budgets_budget" "tarmac" {
  provider     = aws.budgets
  name         = "tarmac-monthly"
  budget_type  = "COST"
  limit_amount = var.monthly_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
