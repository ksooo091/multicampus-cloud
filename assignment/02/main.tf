// pre // 
data "http" "ipinfo" {
  url = "https://ipinfo.io"
}



data "aws_region" "current" {}
locals {
  use_az = [
    "${data.aws_region.current.name}a",
    "${data.aws_region.current.name}c",
  ]
  az_short = [
    "a", "c",
  ]
}

data "hcp_vault_secrets_app" "aws_app" {
  app_name = "AWS"
}


/////// VPC ///////

resource "aws_vpc" "vpc" {

  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "exam-vpc"

  }
}



resource "aws_subnet" "public" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        =  cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)

  tags = {
    Name = "test-subnet-private-2${local.az_short[count.index]}"
  }
}



resource "aws_subnet" "private" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index +2)
  tags = {
    Name = "test-subnet-private-2${local.az_short[count.index]}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "test-igw"
  }
}





resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "test-rtb-public"
  }
}


resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}




//// ec2 ////
resource "aws_security_group" "ubuntu" {
  name        = "ubuntu-sg"
  description = "ubuntu Group Security Groups"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "ubuntu-sg"
  }
}

resource "aws_security_group" "windows" {
  name        = "windows-sg"
  description = "windows Group Security Groups"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "windows-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "ubuntu" {
  security_group_id            = aws_security_group.ubuntu.id
  cidr_ipv4 = format("%s/32", jsondecode(data.http.ipinfo.response_body).ip)
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}
resource "aws_vpc_security_group_ingress_rule" "ubuntu-http" {
  security_group_id            = aws_security_group.ubuntu.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol                  = "tcp"
  from_port               =  80
  to_port                 = 80
}


resource "aws_vpc_security_group_ingress_rule" "windows" {
  security_group_id            = aws_security_group.windows.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol                  = "tcp"
  from_port               =  3389
  to_port                 = 3389
}


resource "aws_vpc_security_group_ingress_rule" "windows-http" {
  security_group_id            = aws_security_group.windows.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol                  = "tcp"
  from_port               =  80
  to_port                 = 80
}
resource "aws_vpc_security_group_egress_rule" "ubuntu" {
  security_group_id = aws_security_group.ubuntu.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_vpc_security_group_egress_rule" "windows" {
  security_group_id = aws_security_group.windows.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}



resource "aws_instance" "windows" {
  ami                         = "ami-0a8daaba1176b337f"
  instance_type               = "t3.large"
  key_name                    = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id                   = aws_subnet.public[0].id

  associate_public_ip_address = true
  tags = {
    Name = "windows"
  }

user_data = <<EOF
<powershell>
Install-WindowsFeature -name Web-Server -IncludeManagementTools
New-Item -Path C:\inetpub\wwwroot\index.html -ItemType File -Value "<html><head><title>Windows Web server</title></head><body><h1>TEAM: EC2 kgs</h1></body></html>" -Force
</powershell>
EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.windows.id]

root_block_device {
  volume_size = 30
}

}

resource "aws_instance" "ubuntu" {
  ami                         = "ami-040c33c6a51fd5d96"
  instance_type               = "t3.medium"
  key_name                    = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id                   = aws_subnet.public[1].id

associate_public_ip_address = true
  tags = {
    Name = "ubuntu"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.ubuntu.id]

root_block_device {
  volume_size = 8
}

user_data = <<EOF
#!/bin/bash
apt-get update
apt-get upgrade -y
apt-get install -y apache2
systemctl start apache2
systemctl enable apache2

echo "<h1>TEAM: EC2 kgs</h1>" > /var/www/html/index.html
EOF


}
