variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID that contains the subnet"
  type        = string
}

variable "container_port" {
  description = "The port your Docker container exposes"
  type        = number
  default     = 80
}

variable "ecr_repository_url" {
  description = "Full ECR repo URL including account ID"
  type        = string
}
