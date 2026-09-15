data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
  tags = { Project = "tarmac", ManagedBy = "terraform" }
  name = var.cluster_name
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs            = local.azs
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 0), cidrsubnet(var.vpc_cidr, 8, 1)]

  # No NAT gateway: $0.056/hr (~$41/mo) buys nothing a demo can see.
  # Public subnets are the deliberate tradeoff — documented in the README.
  enable_nat_gateway = false
  single_nat_gateway = false

  # Public subnets must auto-assign public IPs or nodes cannot reach ECR/STS.
  map_public_ip_on_launch = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  tags = local.tags
}