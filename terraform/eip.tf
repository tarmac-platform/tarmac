# Stable ingress IP for the demo (option B): allocate here, associate to the
# ingress node's ENI imperatively (EKS managed nodes can't take an EIP in
# Terraform). MUST be released at teardown or it bills $0.005/hr idle —
# see Step 10. Re-associate (one CLI call) if Spot replaces the node.
resource "aws_eip" "ingress" {
  domain = "vpc"

  tags = merge(local.tags, { Name = "${local.name}-ingress" })
}

output "ingress_eip" {
  description = "Stable public IP for demo.preview.kwikflo.in (Hostinger A record). Released at teardown."
  value       = aws_eip.ingress.public_ip
}
