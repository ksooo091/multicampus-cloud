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

  cidr_block = "172.100.0.0/16"

  tags = {
    Name = "test-vpc"

  }
}



resource "aws_subnet" "public" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "172.100.${count.index +1 }0.0/24"

  tags = {
    Name = "test-subnet-private-2${local.az_short[count.index]}"
  }
}



resource "aws_subnet" "private" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "172.100.${count.index + 3 }0.0/24"
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


resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[1].id

  tags = {
    Name = "test-natgw"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip" "nat_eip" {

  tags = {
    Name = "natgw-eip"
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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id


  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "test-rtb-private"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


//// ec2 ////
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "web Group Security Groups"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "web-sg"
  }
}

resource "aws_security_group" "was" {
  name        = "was-sg"
  description = "was Group Security Groups"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "was-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "web" {
  security_group_id            = aws_security_group.web.id
  cidr_ipv4 = format("%s/32", jsondecode(data.http.ipinfo.response_body).ip)
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}
resource "aws_vpc_security_group_ingress_rule" "was" {
  security_group_id            = aws_security_group.was.id
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = -1
  from_port               = -1  
  to_port                 = -1  
}
resource "aws_vpc_security_group_egress_rule" "web" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_vpc_security_group_egress_rule" "was" {
  security_group_id = aws_security_group.was.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}



resource "aws_instance" "web" {
  ami                         = data.aws_ami.al-recent.id
  instance_type               = "t2.micro"
  key_name                    = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id                   = aws_subnet.public[0].id

  associate_public_ip_address = true
  tags = {
    Name = "web"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.web.id]

root_block_device {
  volume_size = 8
}

}

resource "aws_instance" "was" {
  ami                         = data.aws_ami.al-recent.id
  instance_type               = "t2.micro"
  key_name                    = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id                   = aws_subnet.private[0].id


  tags = {
    Name = "was"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.was.id]

root_block_device {
  volume_size = 8
}

}
data "aws_ami" "al-recent" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-20*-x86_64"]
  }
  owners = ["137112412989"]
}