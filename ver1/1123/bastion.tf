data "aws_ami" "al-recent" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-20*-x86_64"]
  }
  owners = ["137112412989"]
}

resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Allow SSH"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    cidr_blocks = [format("%s/32", jsondecode(data.http.ipinfo.response_body).ip)]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-SG"
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.al-recent.id
  instance_type = "t3.medium"
  key_name      = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id     = aws_subnet.public[0].id

  associate_public_ip_address = true
  tags = {
    Name = "Bastion Server"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.bastion.id]

  root_block_device {
    volume_size = 8
  }

  user_data = <<EOF
#!/bin/bash

hostnamectl set-hostname Bastion
timedatectl set-timezone Asia/Seoul
yum install mariadb105 docker git -y
usermod -aG docker ec2-user
EOF
}