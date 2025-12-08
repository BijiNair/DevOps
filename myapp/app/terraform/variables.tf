variable "aws_region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet id for EC2 instance"
  type        = string
}

variable "key_name" {
  type = string
  default = "myKey"
}

variable "ecr_repository_url" {
  type = string
}

variable "container_port" {
  default = 8000
}
