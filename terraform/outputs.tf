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