variable "region" {
  description = "AWS region for the platform cluster"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile used by Terraform"
  type        = string
  default     = "cloudsentry"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "tarmac"
}

variable "kubernetes_version" {
  description = "EKS control plane version. Matches the local kind cluster."
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR for the platform VPC"
  type        = string
  default     = "10.42.0.0/16"
}

variable "node_instance_types" {
  description = "Spot node instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 4
}

variable "operator_cidr" {
  description = "Operator public IP (CIDR) allowed to reach the EKS API endpoint. Re-check before every apply: it changes with your ISP."
  type        = string
  default     = "152.58.62.175/32"
}



variable "domain_name" {
  description = "Public DNS zone for preview URLs. Week 12 only creates the zone; delegation is week 13."
  type        = string
  default     = "preview.kwikflo.in"
}
