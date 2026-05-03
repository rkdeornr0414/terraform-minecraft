variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for the Minecraft server. t2.medium provides 2 vCPU / 4 GB RAM, which is the minimum comfortable size for a vanilla 1.21 server with up to 10 players."
  type        = string
  default     = "t2.medium"
}

variable "ami_id" {
  description = "AMI ID for Ubuntu Server 24.04 LTS (us-east-1). Update this value when a newer Ubuntu 24.04 AMI is released in your region."
  type        = string
  default     = "ami-0e86e20dae9224db8"
}

variable "key_name" {
  description = "Name of the existing EC2 key pair used for SSH admin access. The private key (.pem) must be present on the machine running Terraform/Ansible."
  type        = string
  default     = "cs312-key"
}

variable "admin_cidr" {
  description = "CIDR block allowed to reach SSH (port 22) and RCON (port 25575). Set this to your public IP in /32 notation (e.g., 1.2.3.4/32). Never use 0.0.0.0/0 for admin ports."
  type        = string
  # No default: caller must supply their own IP to avoid wide-open SSH.
}

variable "minecraft_port" {
  description = "TCP port Minecraft clients connect on. Default 25565 matches the standard Minecraft Java Edition port."
  type        = number
  default     = 25565
}

variable "rcon_port" {
  description = "TCP port for RCON admin access. Bound to 127.0.0.1 inside the container; only admin_cidr may reach it from outside."
  type        = number
  default     = 25575
}

variable "root_volume_size_gb" {
  description = "Size of the root EBS volume in GiB. 30 GiB comfortably holds the OS, Docker layers, and several world snapshots on disk."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "EBS volume type. gp3 offers better baseline IOPS than gp2 at the same price."
  type        = string
  default     = "gp3"
}

variable "ecr_repo_name" {
  description = "Name of the existing ECR repository that holds Minecraft images. Must already exist; Terraform references it with a data source rather than creating it."
  type        = string
  default     = "minecraft-server"
}

variable "s3_backup_bucket" {
  description = "Name of the existing S3 bucket used for world backups. Must already exist; Terraform references it but does not create or destroy it."
  type        = string
  default     = "mc-backup-934297183"
}

variable "instance_profile_name" {
  description = "Name of the pre-existing IAM instance profile to attach to the EC2 instance. In AWS Academy this is LabInstanceProfile, which wraps LabRole and grants ECR pull and S3 read/write without credentials on disk."
  type        = string
  default     = "LabInstanceProfile"
}

variable "student_id" {
  description = "Student ID embedded in the server MOTD and used as a tag value on all AWS resources for easy identification in a shared Academy account."
  type        = string
  default     = "934297183"
}

variable "minecraft_image_tag" {
  description = "Pinned ECR image tag the Ansible playbook will pull. Change this to roll forward to a new build without touching the playbook."
  type        = string
  default     = "mc-1.21-build1"
}

variable "ansible_user" {
  description = "SSH user Ansible connects as. Ubuntu AMIs use 'ubuntu'."
  type        = string
  default     = "ubuntu"
}

variable "private_key_path" {
  description = "Absolute or relative path to the .pem private key on the machine running Terraform. Used by the null_resource local-exec provisioner to call ansible-playbook."
  type        = string
  default     = "~/Downloads/cs312-key.pem"
}
