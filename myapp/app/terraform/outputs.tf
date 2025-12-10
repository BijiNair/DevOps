output "ec2_public_ip" {
  value       = aws_instance.app_server.public_ip
  description = "Public IP of the EC2 instance"
}

output "security_group_used" {
  value       = local.final_sg_id
  description = "Security Group ID used (existing or newly created)"
}
