output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "region" {
  value = var.region
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "oidc_provider_arn" {
  description = "IRSA trust anchor. Week 13 annotates the Crossplane service account with a role that trusts this."
  value       = module.eks.oidc_provider_arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --profile ${var.aws_profile}"
}

output "preview_zone_id" {
  value = aws_route53_zone.preview.zone_id
}

output "nameservers" {
  description = "Delegate preview.kwikflo.in to these at the registrar (Week 13)."
  value       = aws_route53_zone.preview.name_servers
}

output "crossplane_role_arn" {
  description = "Annotate Crossplane provider SAs with this ( Week 13 IRSA cutover)."
  value       = aws_iam_role.crossplane.arn
}

output "dns_manager_role_arn" {
  description = "Annotate external-dns + cert-manager SAs with this."
  value       = aws_iam_role.dns_manager.arn
}

output "oidc_issuer_url" {
  description = "Bake into the ServiceInfra composition's IAM trust (re-check after any cluster rebuild)."
  value       = module.eks.cluster_oidc_issuer_url
}
output "lb_controller_role_arn" {
  description = "Annotate the aws-load-balancer-controller SA with this."
  value       = aws_iam_role.lb_controller.arn
}
