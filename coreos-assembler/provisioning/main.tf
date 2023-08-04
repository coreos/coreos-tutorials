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
    http = {
      source  = "hashicorp/http"
      version = "2.1.0"
    }
  }
}

provider "aws" {}
provider "ct" {}
provider "http" {}

variable "student_password_hash" {
 type        = string
}

variable "core_user_ssh_pubkey_string" {
 type        = string
}

data "aws_region" "aws_region" {}

data "ct_config" "butane" {
  content = templatefile("cosa-lab-tutorial.bu", {
    student_password_hash = bcrypt(var.student_password_hash)
    core_user_ssh_pubkey_string = var.core_user_ssh_pubkey_string
  })
  strict = true
}

# Gather information about the AWS image for the current region
data "http" "stream_metadata" {
  url = "https://builds.coreos.fedoraproject.org/streams/stable.json"

  request_headers = {
    Accept = "application/json"
  }
}
# Lookup the x86 AWS image for the current AWS region
locals {
  ami = lookup(jsondecode(data.http.stream_metadata.body).architectures.x86_64.images.aws.regions, data.aws_region.aws_region.name).image
}

resource "aws_instance" "cosa-lab-instance" {
  tags = {
    Name = "cosa-lab"
  }
  ami           = local.ami
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
