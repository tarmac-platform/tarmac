output "budget_name" {
  value = aws_budgets_budget.tarmac.name
}

output "budget_limit" {
  value = aws_budgets_budget.tarmac.limit_amount
}

output "dev_public_ip" {
  value = aws_instance.backstage_dev.public_ip
}

output "dev_instance_id" {
  value = aws_instance.backstage_dev.id
}

output "dev_ssh" {
  value = "ssh -i $$HOME/Downloads/devops-raj362.pem ubuntu@${aws_instance.backstage_dev.public_ip}"
}

output "dev_tunnel" {
  value = "ssh -i $$HOME/Downloads/devops-raj362.pem -N -L 3000:localhost:3000 -L 7007:localhost:7007 ubuntu@${aws_instance.backstage_dev.public_ip}"
}
