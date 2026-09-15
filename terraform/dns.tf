# Week 0 left this undone; it is cheap ($0.50/mo) and Week 13's external-dns +
# cert-manager cannot issue real TLS without it. Lives here rather than in
# bootstrap/terraform because the zone is platform infrastructure.
#
# After apply: delegate `preview.kwikflo.in` at Hostinger to the nameservers
# in the `nameservers` output, or nothing resolves externally.
resource "aws_route53_zone" "preview" {
  name = var.domain_name

  tags = merge(local.tags, { Name = "${local.name}-preview-zone" })
}