variable "aws_region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  description = "myKey"
}

variable "ecr_repository_url" {
  description = "131483117382.dkr.ecr.us-east-1.amazonaws.com/myapp"
}

variable "container_port" {
  default = 8000
}
