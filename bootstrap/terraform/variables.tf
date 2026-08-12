variable "monthly_limit" {
  description = "Monthly AWS budget ceiling in USD"
  type        = number
  default     = 50
}

variable "alert_email" {
  description = "Email address for budget alerts (in gitignored terraform.tfvars)"
  type        = string
}

variable "operator_cidr" {
  description = "Your current public IP (CIDR) allowed to SSH to the dev box"
  type        = string
  default     = "152.59.54.112/32"
}

variable "dev_instance_type" {
  description = "EC2 type for the Backstage dev box"
  type        = string
  default     = "t3.large"
}

variable "key_name" {
  description = "Existing AWS key pair for the dev box"
  type        = string
  default     = "devops-raj362"
}

variable "dev_disk_gb" {
  description = "Root EBS size for the dev box"
  type        = number
  default     = 30
}
