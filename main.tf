variable "tutor-ssh-key" {
  default     = "martivo-x220"
  type        = string
  description = "The AWS ssh key to use."
}

variable "aws-region" {
  default     = "eu-central-1"
  type        = string
  description = "The AWS Region to deploy EKS"
}


variable "node-instance-type" {
  default     = "m5.large" 
  type        = string
  description = "Worker Node EC2 instance type"
}

provider "aws" {
  region = var.aws-region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.48.0"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.139.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
     "Name" = "experiment-vpc"
    }
}

data "aws_availability_zone" "a" {
  name = "${var.aws-region}a"
}


data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu-server" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
      name   = "architecture"
      values = ["x86_64"]
  }
}


resource "aws_subnet" "public-a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.139.0.0/24"
  availability_zone_id = data.aws_availability_zone.a.zone_id
  map_public_ip_on_launch = true

  tags = {
     "Name" = "experiment-public-a"
    }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat-a" {
  vpc      = true
}

resource "aws_nat_gateway" "gw-a" {
  allocation_id = aws_eip.nat-a.id
  subnet_id     = aws_subnet.public-a.id
  depends_on = [aws_internet_gateway.gw]

  tags = {
    "Name" = "experiment-gw-a"
  }
}


resource "aws_route_table" "r-public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    "Name" = "experiment-r-public"
  }
}

resource "aws_route_table_association" "ra-public-a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.r-public.id
}



resource "aws_iam_role" "node" {
  name = "experiment-eks-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}


resource "aws_iam_instance_profile" "node" {
  name = "experiment-eks-node-instance-profile"
  role = aws_iam_role.node.name
}

resource "aws_security_group" "node" {
  name        = "experiment-eks-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self = true
  }

  tags = {
     "Name" = "experiment-eks-node-sg"
    }
}


resource "aws_instance" "k3d" {
    ami           = data.aws_ami.ubuntu-server.id
    instance_type = var.node-instance-type
    subnet_id = aws_subnet.public-a.id
    vpc_security_group_ids = [aws_security_group.node.id]
    key_name = var.tutor-ssh-key
    iam_instance_profile = aws_iam_instance_profile.node.name
      root_block_device {
        volume_size = "100"
      }
      tags = {
        "Name" = "experiment-k3d"
      }
    provisioner "file" {
      source      = "install_prequesites.sh"
      destination = "/home/ubuntu/install_prequesites.sh"
    }
    provisioner "remote-exec" {
      inline = ["chmod +x /home/ubuntu/*.sh", "/home/ubuntu/install_prequesites.sh"]
    }
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      host = "${self.public_ip}"
    }
    depends_on = [aws_iam_role.node]
}

data "local_file" "k3d" {
  filename = "run_k3d.sh"
}

data "local_file" "k3dconf" {
  filename = "run_k3d.yaml"
}

resource "null_resource" "k3d" {
  triggers = {
    data = data.local_file.k3d.content
    dataconf = data.local_file.k3dconf.content
    instance = aws_instance.k3d.id
  }
  connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      host = aws_instance.k3d.public_ip
  }
  provisioner "file" {
    source      = "run_k3d.sh"
    destination = "/home/ubuntu/run_k3d.sh"
  }
  provisioner "file" {
    source      = "run_k3d.yaml"
    destination = "/home/ubuntu/run_k3d.yaml"
  }
  provisioner "remote-exec" {
      inline = ["chmod +x /home/ubuntu/*.sh"]
  }
}


resource "aws_instance" "minikube" {
    ami           = data.aws_ami.ubuntu-server.id
    instance_type = var.node-instance-type
    subnet_id = aws_subnet.public-a.id
    vpc_security_group_ids = [aws_security_group.node.id]
    key_name = var.tutor-ssh-key
    iam_instance_profile = aws_iam_instance_profile.node.name
      root_block_device {
        volume_size = "100"
      }
      tags = {
        "Name" = "experiment-minikube"
      }
    provisioner "file" {
      source      = "install_prequesites.sh"
      destination = "/home/ubuntu/install_prequesites.sh"
    }
    provisioner "remote-exec" {
      inline = ["chmod +x /home/ubuntu/*.sh", "/home/ubuntu/install_prequesites.sh"]
    }
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      host = "${self.public_ip}"
    }
    depends_on = [aws_iam_role.node]
}

data "local_file" "minikube" {
  filename = "run_minikube.sh"
}


resource "null_resource" "minikube" {
  triggers = {
    data = data.local_file.minikube.content
    instance = aws_instance.minikube.id
  }
  connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      host = aws_instance.minikube.public_ip
  }
  provisioner "file" {
    source      = "run_minikube.sh"
    destination = "/home/ubuntu/run_minikube.sh"
  }
  provisioner "remote-exec" {
      inline = ["chmod +x /home/ubuntu/*.sh"]
  }
}

resource "aws_instance" "kind" {
    ami           = data.aws_ami.ubuntu-server.id
    instance_type = var.node-instance-type
    subnet_id = aws_subnet.public-a.id
    vpc_security_group_ids = [aws_security_group.node.id]
    key_name = var.tutor-ssh-key
    iam_instance_profile = aws_iam_instance_profile.node.name
      root_block_device {
        volume_size = "100"
      }

      tags = {
        "Name" = "experiment-kind"
      }
    provisioner "file" {
      source      = "install_prequesites.sh"
      destination = "/home/ubuntu/install_prequesites.sh"
    }
    provisioner "remote-exec" {
      inline = ["chmod +x /home/ubuntu/*.sh", "/home/ubuntu/install_prequesites.sh"]
    }
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      host = "${self.public_ip}"
    }
    depends_on = [aws_iam_role.node]
}

data "local_file" "kind" {
  filename = "run_kind.sh"
}

data "local_file" "kindconf" {
  filename = "run_kind.yaml"
}

resource "null_resource" "kind" {
  triggers = {
    data = data.local_file.kind.content
    dataconf = data.local_file.kindconf.content
    instance = aws_instance.kind.id
  }
  connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      host = aws_instance.kind.public_ip
  }
  provisioner "file" {
    source      = "run_kind.sh"
    destination = "/home/ubuntu/run_kind.sh"
  }
  provisioner "file" {
    source      = "run_kind.yaml"
    destination = "/home/ubuntu/run_kind.yaml"
  }
  provisioner "remote-exec" {
      inline = ["chmod +x /home/ubuntu/*.sh"]
  }
}

resource "aws_instance" "microk8s" {
    ami           = data.aws_ami.ubuntu-server.id
    instance_type = var.node-instance-type
    subnet_id = aws_subnet.public-a.id
    vpc_security_group_ids = [aws_security_group.node.id]
    key_name = var.tutor-ssh-key
    iam_instance_profile = aws_iam_instance_profile.node.name
      root_block_device {
        volume_size = "100"
      }

      tags = {
        "Name" = "experiment-microk8s"
      }
    depends_on = [aws_iam_role.node]
}


data "local_file" "microk8s" {
  filename = "run_microk8s.sh"
}

resource "null_resource" "microk8s" {
  triggers = {
    data = data.local_file.microk8s.content
    instance = aws_instance.microk8s.id
  }
  connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      host = aws_instance.microk8s.public_ip
  }
  provisioner "file" {
    source      = "run_microk8s.sh"
    destination = "/home/ubuntu/run_microk8s.sh"
  }
  provisioner "remote-exec" {
      inline = ["chmod +x /home/ubuntu/*.sh"]
  }
}

output "k3d_ip_addr" {
  value       = "ssh ubuntu@${aws_instance.k3d.public_ip}"
  description = "Pulic ip of k3d."
}

output "minikube_ip_addr" {
  value       = "ssh ubuntu@${aws_instance.minikube.public_ip}"
  description = "Pulic ip of minikube."
}

output "kind_ip_addr" {
  value       = "ssh ubuntu@${aws_instance.kind.public_ip}"
  description = "Pulic ip of kind."
}

output "microk8s_ip_addr" {
  value       = "ssh ubuntu@${aws_instance.microk8s.public_ip}"
  description = "Pulic ip of microk8s."
}
