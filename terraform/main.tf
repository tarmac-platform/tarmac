# Platform cluster Terraform — the Week 12 EKS burst.
#
# Budget + Backstage dev box live in bootstrap/terraform (separate state root):
# they outlive the cluster and should not be destroyed with it.
#
# Local state by default so `terraform plan` works with zero setup. Flip to the
# S3 + DynamoDB backend by uncommenting the block below after running
# bootstrap/terraform to create the bucket/table (or `aws s3api create-bucket`).

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Pinned to the provider version cached in bootstrap/terraform/.mirror
      # (6.58.0). The link to releases.hashicorp.com is too slow to pull a
      # fresh 194 MB provider on every init.
      version = ">= 6.28, < 6.59"
    }
  }

  # backend "s3" {
  #   bucket       = "tarmac-tfstate-081382613682"
  #   key          = "platform/terraform.tfstate"
  #   region       = "ap-south-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}