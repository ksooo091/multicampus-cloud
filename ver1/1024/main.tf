// pre // 

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

resource "aws_vpc" "lab-vpc" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "lab-vpc"

  }
}



resource "aws_subnet" "public" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "10.0.${count.index }.0/24"

  tags = {
    Name = "lab-public-subnet-2${local.az_short[count.index]}"
  }
}



resource "aws_subnet" "private" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "10.0.${count.index + 2}.0/24"
  tags = {
    Name = "lab-private-subent-2${local.az_short[count.index]}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.lab-vpc.id

  tags = {
    Name = "lab-igw"
  }
}


resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[1].id

  tags = {
    Name = "lab-natgw"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip" "nat_eip" {

  tags = {
    Name = "multi-natgw-eip"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "lab-igw-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab-vpc.id


  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "multi-nat-rt"
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



/////// ec2 /////////

resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Allow HTTP to Internet"
  vpc_id      = aws_vpc.lab-vpc.id

    ingress {
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "http"

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-SG"
  }
}
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Allow HTTP to lb"
  vpc_id      = aws_vpc.lab-vpc.id

    ingress {
      security_groups = [aws_security_group.alb.id]
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "http"

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-SG"
  }
}


resource "aws_instance" "web" {
  count = 2
  ami                         = data.aws_ami.al-recent.id
  instance_type               = "t3.micro"
  key_name                    = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id                   = aws_subnet.private[count.index].id


  tags = {
    Name = "Amazon Linux 2 Web Server ${local.az_short[count.index]}"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.web.id]
  
user_data = <<EOF
#!/bin/bash
sleep 15
yum update -y
yum install httpd -y
systemctl enable httpd
systemctl start httpd
echo "<h1>WEB${count.index + 1}</h1>" > /var/www/html/index.html
EOF

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

resource "aws_lb_target_group" "lab-tg" {
  name     = "lab-web-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab-vpc.id
}

resource "aws_lb_target_group_attachment" "tg-att" {
  count   =   2 
  target_group_arn = aws_lb_target_group.lab-tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

resource "aws_lb" "alb" {
  name               = "web-alb"
  // 기본 -> internet-facing
  internal = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

 // enable_deletion_protection = true

 

}

resource "aws_lb_listener" "alb_listner" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lab-tg.arn
  }
}