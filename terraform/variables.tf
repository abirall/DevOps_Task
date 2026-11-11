
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "python-devops-task"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production."
  }
}

variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the application over HTTP; set to a trusted range"
  type        = list(string)
  default     = []
}

variable "container_port" {
  description = "Application container port"
  type        = number
  default     = 5000
}

variable "image_tag" {
  description = "Initial ECR tag placeholder; CI deploys the first application image"
  type        = string
  default     = "bootstrap"
}

variable "root_volume_size" {
  description = "EC2 root volume size in GB"
  type        = number
  default     = 12
}

variable "log_retention_days" {
  description = "CloudWatch log retention period"
  type        = number
  default     = 14
}

variable "enable_public_ip" {
  description = "Whether to assign a public IP to the application instance"
  type        = bool
  default     = true
}

variable "ecr_force_delete" {
  description = "Allow Terraform to delete a non-empty ECR repository"
  type        = bool
  default     = false
}

