# configured aws provider with proper credentials
provider "aws" {
  region                   = "us-east-2"
  shared_config_files      = ["/Users/austi/.aws/conf"]
  shared_credentials_files = ["/Users/austi/.aws/credentials"]
  profile                  = "austin"
}


# Create a remote backend for your terraform 
terraform {
  backend "s3" {
    bucket         = "austins-k8s-tfstate"
    dynamodb_table = "k8s-state"
    key            = "LockID"
    region         = "us-east-1"
    profile        = "austin"
  }
}

# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {

  tags = {
    Name = "default vpc"
  }
}


# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}


# create default subnet if one does not exit
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet"
  }
}


# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on required ports"
  vpc_id      = resource.aws_default_vpc.default_vpc.id

  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "k8s etcd access"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "k8s1 kubelete access"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "k8s2 api server access"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "k8s3 access"
    from_port   = 31111
    to_port     = 31111
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "k8s5 nodeport services access"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "scheduler access"
    from_port   = 10251
    to_port     = 10251
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "controller access"
    from_port   = 10252
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s server sg"
  }
}


resource "tls_private_key" "self-eks" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.self-eks.public_key_openssh
}

# launch the ec2 instance
resource "aws_instance" "ec2_instance" {
  ami                    = "ami-0f30a9c3a48f3fa79"
  instance_type          = "t3.medium"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = aws_key_pair.generated_key.key_name
  user_data              = file("install_k8s.sh")
  count                  = 3

  tags = {
    Name = "kubernetes server"
  }

}


# print the url of the container
output "container_url" {
  value = ["${aws_instance.ec2_instance.*.public_ip}"]
}

# Print the Private Key
output "private_key" {
  value     = tls_private_key.self-eks.private_key_pem
  sensitive = true
}
