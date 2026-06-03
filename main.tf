terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.24"
    }
  }
  required_version = ">=1.14"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "jenkins" {
  ami           = "ami-091138d0f0d41ff90"
  instance_type = "t3.micro"

  tags = {
    Name = "jenkins-server"
  }
}
