terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "ap-northeast-1"
  access_key = "access_key"
  secret_key = "secret_key"
}

# 1. Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "my_gw" {
  vpc_id = aws_vpc.my_vpc.id
}

# 3. Create Route Table
resource "aws_route_table" "my_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.my_gw.id
  }

  route {
      ipv6_cidr_block = "::/0"
      gateway_id      = aws_internet_gateway.my_gw.id
  }

}

# 4. Create Subnet
resource "aws_subnet" "my_sn" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
}

# 5. Create Route table Association / Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.my_sn.id
  route_table_id = aws_route_table.my_rt.id
}

# 6. Create Security Group to allow port
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
      description = "SSH TLS from VPC"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
  }

}

# 7. Create Network Interface /with an ip in the subnet that was created in step 4
resource "aws_network_interface" "my_ni" {
  subnet_id       = aws_subnet.my_sn.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_tls.id]
}

# 8. Create EIP /Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.my_ni.id
  associate_with_private_ip = "10.0.1.50"
}

# 9. Create new key pair
resource "aws_key_pair" "triaws" {
  key_name   = "triaws"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICpznzuKoNKKUe0r1nLVmz78H8ohMJ8o84BIuJXIi2rK tribuivtr@gmail.com"
}

# 9. Create 1 Instance
resource "aws_instance" "my_instance" {
  ami           = "ami-09ebacdc178ae23b7"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.triaws.key_name

  network_interface {
    network_interface_id = aws_network_interface.my_ni.id
    device_index         = 0
  }

}

# Output
output "public_ip" {
  value       = aws_eip.one.public_ip
  sensitive   = false
  description = "Show public IP"
}