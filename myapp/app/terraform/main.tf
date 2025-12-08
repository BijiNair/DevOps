provider "aws" {
  region = var.aws_region
}

# ---------- IAM ROLE FOR EC2 TO ACCESS ECR ----------
resource "aws_iam_role" "ec2_role" {
  name = "ec2_ecr_pull_role"

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

# ---------- SECURITY GROUP ----------
resource "aws_security_group" "ec2_sg_tf" {
  name        = "ec2_sg_tf"
  description = "Allow HTTP"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- EC2 INSTANCE ----------
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["137112412989"] # Amazon
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.id
  vpc_security_group_ids = [aws_security_group.ec2_sg_tf.id]

  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region         = var.aws_region
    ecr_repository_url = var.ecr_repository_url
    container_port     = var.container_port
  })

  tags = {
    Name = "ECR-EC2-App"
  }
}
