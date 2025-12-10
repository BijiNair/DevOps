provider "aws" {
  region = var.aws_region
}

# ----------------------------------------------------------
# IAM ROLE FOR EC2 TO ACCESS ECR
# ----------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2_ecr_pull_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecr_policy" {
  name = "ecr_policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_ecr_profile"
  role = aws_iam_role.ec2_role.id
}

# ----------------------------------------------------------
# SECURITY GROUP: USE EXISTING IF PRESENT, ELSE CREATE NEW
# ----------------------------------------------------------

# 1. Attempt lookup
data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-name"
    values = ["ec2_sg_tf"]
  }

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  # do not fail if not found
  lifecycle {
    postcondition {
      condition     = true
      error_message = "Will create new SG if not found"
    }
  }
}

# 2. Create new SG only if none exists
resource "aws_security_group" "ec2_sg_tf" {
  count = length(data.aws_security_group.existing_sg.id) == 0 ? 1 : 0

  name        = "ec2_sg_tf"
  description = "Allow container traffic and SSH"
  vpc_id      = var.vpc_id

  tags = {
    Name = "ec2_sg_tf"
  }
}

# 3. Final SG ID selection
locals {
  final_sg_id = length(data.aws_security_group.existing_sg.id) > 0 ?
    data.aws_security_group.existing_sg.id :
    aws_security_group.ec2_sg_tf[0].id
}

# 4. SG Rules (always attach/update)
resource "aws_security_group_rule" "http_rule" {
  type              = "ingress"
  from_port         = var.container_port
  to_port           = var.container_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = local.final_sg_id
}

resource "aws_security_group_rule" "ssh_rule" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # adjust for security
  security_group_id = local.final_sg_id
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = local.final_sg_id
}

# ----------------------------------------------------------
# EC2 INSTANCE
# ----------------------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["137112412989"]
}

resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  associate_public_ip_address = true

  vpc_security_group_ids = [local.final_sg_id]

  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region         = var.aws_region
    ecr_repository_url = var.ecr_repository_url
    container_port     = var.container_port
  })

  tags = {
    Name = "ECR-EC2-App"
  }
}
