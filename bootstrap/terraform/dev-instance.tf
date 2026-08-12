# Backstage dev box. Backstage docs require a Unix-like OS + GNU toolchain
# (isolated-vm needs python3/make/g++); Windows has neither, hence EC2.
#
# It never talks to the cluster: Backstage -> GitHub API -> ArgoCD pulls -> kind.
# So no VPN/tunnel to the laptop is needed, and kind stays local and free.
#
# Stop (not destroy) between sessions: EBS persists your checkout, compute stops billing.

data "aws_ssm_parameter" "ubuntu_2404" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "backstage_dev" {
  name        = "tarmac-backstage-dev"
  description = "SSH from operator IP only. Backstage 3000/7007 reached via SSH tunnel."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from operator only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.operator_cidr]
  }

  # ponytail: no 3000/7007 ingress on purpose. A fresh Backstage runs guest auth
  # with no login and can create GitHub repos - never expose it publicly.
  # Use: ssh -L 3000:localhost:3000 -L 7007:localhost:7007
  egress {
    description = "all outbound (apt, npm, github)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_instance" "backstage_dev" {
  ami                         = data.aws_ssm_parameter.ubuntu_2404.value
  instance_type               = var.dev_instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.backstage_dev.id]
  associate_public_ip_address = true

  # no EIP: an Elastic IP bills while the instance is stopped. Public IP
  # changes on each start - fetch it with the dev_ip output.

  root_block_device {
    volume_size           = var.dev_disk_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data_replace_on_change = false
  user_data                   = <<-CLOUDINIT
    #!/bin/bash
    set -euxo pipefail

    apt-get update
    # build-essential + python3 are what isolated-vm needs to compile
    apt-get install -y build-essential python3 git curl ca-certificates gnupg

    # Node 22 (Backstage requires Active LTS; 22 or 24)
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs

    # Backstage pins Yarn 4.4.1 via corepack
    corepack enable

    # Docker (Backstage prereq; used by techdocs generation)
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    usermod -aG docker ubuntu

    # ponytail: 2GB swap. t3.large has 8GB and Backstage's yarn install + tsc
    # spikes near it; swap turns a hard OOM kill into a slow build.
    # Raise if `yarn start` still gets OOM-killed.
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    touch /home/ubuntu/.cloud-init-done
    chown ubuntu:ubuntu /home/ubuntu/.cloud-init-done
  CLOUDINIT

  tags = merge(local.tags, { Name = "tarmac-backstage-dev" })
}
