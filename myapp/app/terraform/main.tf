provider "aws" {
  region = "us-east-1"
}

# Create EC2 instance (simple example)
resource "aws_instance" "app_server" {
  ami           = "ami-080c353f4798a202f" # Amazon Linux 2
  instance_type = "t2.micro"
  subnet_id = "subnet-0fc001f54f0689d53"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install docker -y
              service docker start
              docker run -d -p 80:8000 mydockerhubusername/myapp:latest
              EOF

  tags = {
    Name = "myapp-server"
  }
}
