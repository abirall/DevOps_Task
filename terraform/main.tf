
# --------------------------------------------------
# DATA SOURCES
# --------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "selected" {
  id = sort(data.aws_subnets.default.ids)[0]
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --------------------------------------------------
# ECR REPOSITORY
# --------------------------------------------------

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# --------------------------------------------------
# CLOUDWATCH LOG GROUP
# --------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/${var.environment}/app"
  retention_in_days = var.log_retention_days
}

# --------------------------------------------------
# SECURITY GROUP
# --------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for Python application"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Application HTTP access"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Outbound access for ECR, SSM and AWS services"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg"
  }
}

# --------------------------------------------------
# IAM ROLE
# --------------------------------------------------

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

# ECR read permissions

resource "aws_iam_role_policy" "ecr_read" {
  name = "ecr-read-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]

        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

# CloudWatch Logs permissions

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "cloudwatch-logs-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]

      Resource = "${aws_cloudwatch_log_group.app.arn}:*"
    }]
  })
}

# SSM access without SSH keys

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --------------------------------------------------
# INSTANCE PROFILE
# --------------------------------------------------

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-${var.environment}-profile"
  role = aws_iam_role.ec2_role.name
}

# --------------------------------------------------
# EC2 INSTANCE
# --------------------------------------------------

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.selected.id
  associate_public_ip_address = var.enable_public_ip

  monitoring = true

  disable_api_termination = var.environment == "production"

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  iam_instance_profile = aws_iam_instance_profile.app.name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region     = var.aws_region
    image_uri      = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
    container_port = var.container_port
    log_group      = aws_cloudwatch_log_group.app.name
    environment    = var.environment
  })

  user_data_replace_on_change = false

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2"
  }

  depends_on = [
    aws_iam_role_policy.ecr_read,
    aws_iam_role_policy.cloudwatch_logs,
    aws_iam_role_policy_attachment.ssm
  ]
}
