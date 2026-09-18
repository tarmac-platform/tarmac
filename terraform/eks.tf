module "eks" {
  source = "terraform-aws-modules/eks/aws"
  # 21.21+ requires aws provider >= 6.59; the local mirror caps at 6.58.0.
  version = ">= 21.15, < 21.21"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Public endpoint so the operator can reach the API without a bastion.
  # Restricted to the operator CIDR; private endpoint stays on for node traffic.
  endpoint_public_access       = true
  endpoint_public_access_cidrs = [var.operator_cidr]
  endpoint_private_access      = true

  # IRSA: required so Crossplane can drop the static IAM user key and assume a
  # role from the pod. Week 13 wires the service account annotation.
  enable_irsa = true

  # Adds the operator IAM user as cluster admin via an access entry instead of
  # editing aws-auth by hand.
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns    = {}
    kube-proxy = {}
    # Prefix delegation lifts the per-node pod cap: t3.medium goes from ~17 pods
    # (1 ENI-IP per pod) to ~110 (/28 prefixes). Without this the full platform
    # stack fills both nodes and Crossplane provider pods wedge in Pending.
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  # ELB creation is blocked on this account (AWS Support ticket pending), so
  # ingress-nginx runs in hostPort mode on the nodes. Open 80/443 to the
  # internet on the node SG so preview URLs resolve. Revert to the NLB path
  # (and drop these rules) once the account can create load balancers.
  node_security_group_additional_rules = {
    ingress_http = {
      description = "ingress-nginx hostPort HTTP"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ingress_https = {
      description = "ingress-nginx hostPort HTTPS"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  eks_managed_node_groups = { default = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = var.node_instance_types
    capacity_type  = "SPOT"

    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size

    # Nodes land in public subnets (no NAT) and need public IPs to reach
    # ECR/STS/sigstore. The module's node SG governs inbound.
    subnet_ids = module.vpc.public_subnets

    labels = {
      role = "tenant"
    }

    tags = merge(local.tags, { Name = "${local.name}-node" })
    }
  }

  tags = local.tags
}
