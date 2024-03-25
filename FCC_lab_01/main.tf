terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.20"
    }
  }

  required_version = ">= 1.2.0"

}

provider "aws" {
  region = "ap-southeast-1"
}

# Step by Step tutorial
# 1. Create VPC
# 2. Create internet gateway
# 3. Create custom route table
# 4. Create a subnet
# 5. associate subnet with route table
# 6. Create security group allow inbound port 22,443,80
# 7. Create network interface with ip subet create from step 4
# 8. Assign an Elastic IP to the internet gateway create from step 2
# 9. Create Ubuntu server and install/enable apache2


# show output
# 1. server public IP
# 2. server private IP
# 3. server instance id

# note: create key pair first on AWS console - name: FCC_kp_01.pem

# 1. Create VPC
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name        = "production"
    Description = "My lab 1 of FCC tutorial"
  }
}


# 2. Create internet gateway
resource "aws_internet_gateway" "main-igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "production-igw"
  }
}


# 3. Create custom route table
resource "aws_route_table" "main-rtb" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.main-igw.id
  }

  tags = {
    Name = "production-rtb"
  }
}

# 4. Create a subnet
resource "aws_subnet" "public-subnet-1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr_block 
  availability_zone = var.public_subnet_availibility_zone 

  tags = {
    Name        = "production-public-subnet-1"
    Description = "public subnet 1 of production vpc"
  }
}

# 5. associate subnet with route table
resource "aws_route_table_association" "associate-subnet-rtb" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.main-rtb.id
}


# 6. Create security group allow inbound port 22,443,80
resource "aws_security_group" "production-sg" {
  name        = "production-sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow web traffic"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    description = "open for port 443 - HTTPS"
  }


  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    description = "open for port 80 - HTTP"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    description = "open for port 22 - SSH"
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow-web"
  }
}

# 7. Create network interface with ip subet create from step 4

resource "aws_network_interface" "proc-network-intf" {
  subnet_id       = aws_subnet.public-subnet-1.id
  security_groups = [aws_security_group.production-sg.id]
}

# 7.1 create timesleep resource
resource "time_sleep" "proc-network-intf-delay" {
  create_duration = "30s"
  depends_on = [
    aws_network_interface.proc-network-intf
  ]
}

# 8. Assign an Elastic IP to the internet gateway create from step 2

resource "aws_eip" "prod-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.proc-network-intf.id
  associate_with_private_ip = aws_network_interface.proc-network-intf.private_ip
  depends_on                = [time_sleep.proc-network-intf-delay, aws_internet_gateway.main-igw]
}

# 9. Create Ubuntu server and install/enable apache2
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "prod-instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_server_instance 

  tags = {
    Name = "prod-webserver-instance"
  }

  availability_zone = var.public_subnet_availibility_zone 
  key_name          = "FCC_kp_01"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.proc-network-intf.id
  }

  user_data = <<-EOF
                            #!/bin/bash
                            sudo apt update -y
                            sudo apt install apache2 -y
                            sudo systemctl start apache2
                            sudo systemctl enable apache2
                            sudo bash -c "echo your first webserver > /var/www/html/index.html"
                            EOF
}


# show outputs
output "server_public_IP" {
    value = aws_eip.prod-eip.public_ip
}

output "server_private_IP" {
    value = aws_instance.prod-instance.private_ip
}

output "server_instance_id" {
    value = aws_instance.prod-instance.id
}