terraform {
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = "0.13.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

provider "ct" {}

variable "student_password_hash" {
 type        = string
 default     = "REPLACE"
}

data "ct_config" "butane" {
  content = templatefile("cosa-lab-tutorial.bu", {
    student_password_hash = bcrypt(var.student_password_hash)
  })
  strict = true
}

resource "aws_instance" "cosa-lab-instance" {
  tags = {
    Name = "cosa-lab"
  }
  ami           = "ami-0ea3c2efdcead938c"
  instance_type = "c5n.metal"
  user_data     = data.ct_config.butane.rendered
  associate_public_ip_address = "true"
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = aws_subnet.private_subnets[0].id
  root_block_device {
      volume_size = "200"
      volume_type = "gp3"
  }
}

output "instance_ip_addr" {
  value = aws_instance.cosa-lab-instance.public_ip
}
