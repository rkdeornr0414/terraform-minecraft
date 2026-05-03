output "instance_id" {
  description = "EC2 instance ID of the Minecraft server."
  value       = aws_instance.minecraft.id
}

output "public_ip" {
  description = "Public IP address to use for nmap verification and Minecraft client connections."
  value       = aws_instance.minecraft.public_ip
}

output "public_dns" {
  description = "Public DNS hostname of the EC2 instance."
  value       = aws_instance.minecraft.public_dns
}

output "security_group_id" {
  description = "ID of the Minecraft security group."
  value       = aws_security_group.minecraft.id
}

output "ecr_image_url" {
  description = "Full ECR image URL used by the Ansible playbook."
  value       = "${local.ecr_url}:${var.minecraft_image_tag}"
}

output "ssh_command" {
  description = "Copy-paste SSH command to log into the server."
  value       = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.minecraft.public_ip}"
}

output "nmap_command" {
  description = "nmap command for video checkpoint 2 – verifies port 25565 is open and shows MOTD."
  value       = "nmap -sV -Pn -p T:25565 ${aws_instance.minecraft.public_ip}"
}
