output "budget_name" {
  value = aws_budgets_budget.tarmac.name
}

output "budget_limit" {
  value = aws_budgets_budget.tarmac.limit_amount
}

output "alert_email" {
  value = aws_budgets_budget.tarmac.notification[0].subscriber_email_addresses
}
