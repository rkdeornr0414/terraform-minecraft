terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ── State Management ────────────────────────────────────────────────────────
  # State is stored LOCALLY in terraform.tfstate (default).
  # Rationale for AWS Academy: Academy sessions are ephemeral and S3-backed
  # remote state would require a persistent bucket with versioning that
  # survives session expiry.  Local state is committed to the Git repository
  # (terraform.tfstate is git-ignored in production; here it is intentionally
  # kept local and treated as a single-operator workflow).
  # If you move to a persistent AWS account, replace this block with:
  #
  #   backend "s3" {
  #     bucket         = "mc-tfstate-<account-id>"
  #     key            = "minecraft/terraform.tfstate"
  #     region         = "us-east-1"
  #     dynamodb_table = "mc-tfstate-lock"
  #     encrypt        = true
  #   }
  # ────────────────────────────────────────────────────────────────────────────
}

provider "aws" {
  region = var.aws_region
}

# ── Data sources: reference pre-existing resources ──────────────────────────

# Default VPC – AWS Academy accounts always have this; no need to create one.
data "aws_vpc" "default" {
  default = true
}

# A public subnet inside the default VPC.  We pick the first one returned.
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Pre-existing IAM instance profile created by AWS Academy (LabInstanceProfile
# wraps LabRole).  Attaching it lets the EC2 instance authenticate to ECR and
# write to S3 via instance-metadata credentials – no keys on disk.
data "aws_iam_instance_profile" "lab" {
  name = var.instance_profile_name
}

# ── Security Group 

resource "aws_security_group" "minecraft" {
  name        = "minecraft-sg-${var.student_id}"
  description = "Minecraft server: Minecraft port open to internet; SSH/RCON restricted to operator"
  vpc_id      = data.aws_vpc.default.id

  # Minecraft clients – open to the public internet (players connect from anywhere)
  ingress {
    description = "Minecraft Java Edition"
    from_port   = var.minecraft_port
    to_port     = var.minecraft_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH – operator only; admin_cidr must be set to your /32 IP
  ingress {
    description = "SSH admin access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # RCON – operator only; used by mcrcon for in-service administration
  ingress {
    description = "RCON admin"
    from_port   = var.rcon_port
    to_port     = var.rcon_port
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # All outbound traffic allowed (needed for ECR pull, S3 backup, apt updates)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "minecraft-sg"
    StudentID = var.student_id
    ManagedBy = "terraform"
  }
}

# ── EC2 Instance

resource "aws_instance" "minecraft" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = tolist(data.aws_subnets.public.ids)[0]
  vpc_security_group_ids      = [aws_security_group.minecraft.id]
  associate_public_ip_address = true

  # Attach LabInstanceProfile so the host can call ECR and S3 without
  # storing AWS credentials on disk.
  iam_instance_profile = data.aws_iam_instance_profile.lab.name

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size_gb
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name      = "minecraft-root"
      StudentID = var.student_id
      ManagedBy = "terraform"
    }
  }

  # Minimal cloud-init: install Ansible and clone this repo so the instance
  # could self-configure if needed; all real config lives in the playbook.
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y software-properties-common
    add-apt-repository --yes --update ppa:ansible/ansible
    apt-get install -y ansible git
  EOF

  tags = {
    Name      = "minecraft-server-${var.student_id}"
    StudentID = var.student_id
    ManagedBy = "terraform"
  }
}

# ── Ansible Integration 
# null_resource with local-exec chains Ansible directly after terraform apply.
# The provisioner runs on the machine executing Terraform (WSL), not on EC2.
# It waits 30 s for SSH to become available before handing off to Ansible.

resource "null_resource" "ansible_provision" {
  # Re-run whenever the instance is replaced.
  triggers = {
    instance_id = aws_instance.minecraft.id
  }

  provisioner "local-exec" {
    command = <<-CMD
      echo "Waiting for SSH to become available..."
      sleep 30

      # Write a temporary inventory file pointing at the new public IP.
      cat > /tmp/mc_inventory.ini <<INV
      [minecraft]
      ${aws_instance.minecraft.public_ip} ansible_user=${var.ansible_user} ansible_ssh_private_key_file=${var.private_key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
      INV

      ansible-playbook \
        -i /tmp/mc_inventory.ini \
        ../ansible/playbook.yml \
        --extra-vars "ecr_repo_url=${data.aws_iam_instance_profile.lab.name != "" ? "${local.ecr_url}" : ""} image_tag=${var.minecraft_image_tag} s3_bucket=${var.s3_backup_bucket} aws_region=${var.aws_region} student_id=${var.student_id}"
    CMD
  }

  depends_on = [aws_instance.minecraft]
}

locals {
  ecr_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repo_name}"
}

data "aws_caller_identity" "current" {}
