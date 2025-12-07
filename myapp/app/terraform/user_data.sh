#!/bin/bash
yum update -y
yum install -y docker amazon-linux-extras
service docker start
usermod -a -G docker ec2-user

# Login to ECR
aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin ${ecr_repository_url}

# Pull latest image
docker pull ${ecr_repository_url}:latest

# Run container
docker run -d -p 80:${container_port} ${ecr_repository_url}:latest
