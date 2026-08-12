output "budget_name" {
  value = aws_budgets_budget.tarmac.name
}

output "budget_limit" {
  value = aws_budgets_budget.tarmac.limit_amount
}
