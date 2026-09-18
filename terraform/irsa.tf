# Week 13 IRSA roles. Static keys die here: Crossplane, external-dns and
# cert-manager all assume these via the EKS OIDC provider — no Secrets in git.
data "aws_caller_identity" "current" {}

locals {
  oidc_issuer = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

# Scoped policy cloned from the kind-era IAM user (tarmac-crossplane-local):
# RDS + S3 + tarmac-* IAM roles only. Same blast radius, no static key.
resource "aws_iam_policy" "crossplane_scoped" {
  name = "tarmac-crossplane-scoped-role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RdsLifecycle"
        Effect   = "Allow"
        Action   = ["rds:CreateDBInstance", "rds:ModifyDBInstance", "rds:DeleteDBInstance", "rds:DescribeDBInstances", "rds:AddTagsToResource", "rds:ListTagsForResource"]
        Resource = "arn:aws:rds:${var.region}:${data.aws_caller_identity.current.account_id}:db:*"
      },
      {
        Sid      = "RdsDescribeAny"
        Effect   = "Allow"
        Action   = ["rds:DescribeDBInstances"]
        Resource = "*"
      },
      {
        Sid      = "S3ServiceBuckets"
        Effect   = "Allow"
        Action   = ["s3:CreateBucket", "s3:DeleteBucket", "s3:ListBucket", "s3:GetBucketLocation", "s3:GetBucket*", "s3:GetAccelerateConfiguration", "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration", "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration", "s3:GetReplicationConfiguration", "s3:PutBucketTagging", "s3:PutBucketPublicAccessBlock", "s3:DeleteBucketPublicAccessBlock", "s3:PutBucketAcl", "s3:PutBucketVersioning", "s3:GetBucketVersioning"]
        Resource = "arn:aws:s3:::tarmac-*"
      },
      {
        Sid      = "Ec2ReadOnlyForRdsNetworking"
        Effect   = "Allow"
        Action   = ["ec2:DescribeSubnets", "ec2:DescribeVpcs", "ec2:DescribeAvailabilityZones", "ec2:DescribeSecurityGroups"]
        Resource = "*"
      },
      {
        Sid      = "IamRolesForServicesOnly"
        Effect   = "Allow"
        Action   = ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:UntagRole", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListInstanceProfilesForRole", "iam:ListAttachedRolePolicies", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PassRole"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/tarmac-*"
      },
      {
        Sid      = "AllowServiceLinkedRoleForRds"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringLike = { "iam:AWSServiceName" : "rds.amazonaws.com" }
        }
      },
      {
        Sid      = "StsSelfCheck"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
  tags = local.tags
}

# Crossplane provider pods. Wildcard SA: Crossplane names provider SAs itself
# (upbound-provider-aws-*, family included); all SAs in crossplane-system are
# platform components, so the blast radius stays inside the platform.
resource "aws_iam_role" "crossplane" {
  name = "tarmac-crossplane"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.oidc_issuer}:aud" : "sts.amazonaws.com" }
        StringLike   = { "${local.oidc_issuer}:sub" : "system:serviceaccount:crossplane-system:upbound-provider-*" }
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "crossplane_scoped" {
  role       = aws_iam_role.crossplane.name
  policy_arn = aws_iam_policy.crossplane_scoped.arn
}

# Shared DNS role: external-dns (A records) + cert-manager (DNS-01 TXT) need
# identical Route53 rights on the preview zone, so one role, two SA subjects.
resource "aws_iam_policy" "dns_manager" {
  name = "tarmac-dns-manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PreviewZoneRecords"
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
        Resource = aws_route53_zone.preview.arn
      },
      {
        Sid      = "Route53ReadOnly"
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones", "route53:GetChange"]
        Resource = "*"
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role" "dns_manager" {
  name = "tarmac-dns-manager"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:aud" : "sts.amazonaws.com"
          "${local.oidc_issuer}:sub" : [
            "system:serviceaccount:external-dns:external-dns",
            "system:serviceaccount:cert-manager:cert-manager"
          ]
        }
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "dns_manager" {
  role       = aws_iam_role.dns_manager.name
  policy_arn = aws_iam_policy.dns_manager.arn
}

# AWS Load Balancer Controller: EKS 1.32 has no in-tree service LB provisioner,
# so ingress-nginx's `type: LoadBalancer` + NLB annotations need this controller
# to actually create the NLB. IRSA-authenticated; policy is the upstream v2.9.2
# recommended policy (vendored as lbc-iam-policy.json).
resource "aws_iam_policy" "lb_controller" {
  name   = "tarmac-lb-controller"
  policy = file("${path.module}/lbc-iam-policy.json")
  tags   = local.tags
}

resource "aws_iam_role" "lb_controller" {
  name = "tarmac-lb-controller"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:aud" : "sts.amazonaws.com"
          "${local.oidc_issuer}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}
