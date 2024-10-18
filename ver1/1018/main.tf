# vpc name - multi-vpc 10.0.0.0/16
# AZ - 4개 A, C
# igw -multi-igw
# NAT - multi-nat - c zone
# 2a에 ec2 생성. name - Web-server public ip, sg - 80 anywhere, 22 myip



/////// VPC ///////

resource "aws_vpc" "multi-vpc" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "multi-vpc"

  }
}



resource "aws_subnet" "public-subnet-2a" {
  vpc_id            = aws_vpc.multi-vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "multi-public-subnet-2a"
  }
}

resource "aws_subnet" "public-subnet-2c" {
  vpc_id            = aws_vpc.multi-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "multi-public-subnet-2c"
  }
}

resource "aws_subnet" "private-subent-2a" {
  vpc_id            = aws_vpc.multi-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "multi-private-subent-2a"
  }
}

resource "aws_subnet" "private-subnet-2c" {
  vpc_id            = aws_vpc.multi-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "multi-private-subent-2c"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.multi-vpc.id

  tags = {
    Name = "multi-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.multi-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "multi-igw-rt"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.multi-vpc.id


  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "multi-nat-rt"
  }
}


resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.public-subnet-2a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public-c" {
  subnet_id      = aws_subnet.public-subnet-2c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private-a" {
  subnet_id      = aws_subnet.private-subent-2a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private-c" {
  subnet_id      = aws_subnet.private-subnet-2c.id
  route_table_id = aws_route_table.private.id
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public-subnet-2c.id

  tags = {
    Name = "multi-natgw"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip" "nat_eip" {

  tags = {
    Name = "multi-natgw-eip"
  }
}

//////// EC2 /////////


resource "aws_instance" "web" {
  // ami           = data.aws_ami.al.id
  ami                         = data.aws_ami.al-recent.id
  instance_type               = "t4g.small"
  key_name                    = var.keypair
  subnet_id                   = aws_subnet.public-subnet-2a.id
  associate_public_ip_address = true

  tags = {
    Name = "Web-server"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.web-server.id]

}



resource "aws_security_group" "web-server" {
  name        = "webserver-sg"
  description = "Allow HTTP, SSH"
  vpc_id      = aws_vpc.multi-vpc.id

  dynamic "ingress" {
    for_each = {
      80 = { protocol = "tcp", cidr = "0.0.0.0/0" }
      22 = { protocol = "tcp", cidr = var.myip }

    }
    content {
      cidr_blocks = [ingress.value.cidr]
      from_port   = ingress.key
      to_port     = ingress.key
      protocol    = ingress.value.protocol
      description = ingress.value.protocol
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-server-SG"
  }
}

output "web-publicip" {
  value = aws_instance.web.public_ip
}

data "aws_ami" "al-recent" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-20*-arm64"]
  }
owners = ["137112412989"] 
}