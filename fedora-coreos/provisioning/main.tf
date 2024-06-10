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
  region = "eu-central-1"
}
provider "ct" {}

variable "student_password_hash" {
 type        = string
}

variable "core_user_ssh_pubkey_string" {
 type        = string
}

data "ct_config" "butane" {
  content = templatefile("fcos-lab-tutorial.bu", {
    student_password_hash = bcrypt(var.student_password_hash)
    core_user_ssh_pubkey_string = var.core_user_ssh_pubkey_string
  })
  strict = true
}

resource "aws_instance" "fcos-lab-instance" {
  tags = {
    Name = "fcos-lab"
  }
  ami           = "ami-06128ecf4b4101217"
  instance_type = "c5n.metal"
  user_data     = data.ct_config.butane.rendered
  associate_public_ip_address = "true"
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = aws_subnet.private_subnets[0].id
  root_block_device {
      volume_size = "100"
      volume_type = "gp2"
  }
}

output "instance_ip_addr" {
  value = aws_instance.fcos-lab-instance.public_ip
}
