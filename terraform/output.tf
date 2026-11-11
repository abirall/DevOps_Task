
output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.app.public_ip
}

output "application_url" {
  description = "Application URL"
  value       = "http://${aws_instance.app.public_dns}"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "cloudwatch_log_group" {
  description = "Application CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "security_group_id" {
  description = "Application security group ID"
  value       = aws_security_group.app.id
}

output "ssm_connection_command" {
  description = "Connect to EC2 using AWS Systems Manager"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}
