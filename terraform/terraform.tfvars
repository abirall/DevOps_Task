project_name        = "python-devops-task"
environment         = "staging"
aws_region          = "ap-south-1"
instance_type       = "t3.micro"
container_port      = 5000
root_volume_size    = 12
log_retention_days  = 14
allowed_cidr_blocks = ["YOUR_PUBLIC_IP/32"]
