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
    Name = "vpc"
  }
}



resource "aws_subnet" "public" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)

  tags = {
    Name = "public-subnet-${local.az_short[count.index]}"
  }
}



resource "aws_subnet" "web" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 2)
  tags = {
    Name = "web-subent-${local.az_short[count.index]}"
  }
}

resource "aws_subnet" "was" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 4)
  tags = {
    Name = "was-subent-${local.az_short[count.index]}"
  }
}

resource "aws_subnet" "db" {
  count             = 2
  availability_zone = local.use_az[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 6)
  tags = {
    Name = "db-subent-${local.az_short[count.index]}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "igw"
  }
}


resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[1].id

  tags = {
    Name = "natgw"
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
    Name = "igw-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id


  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "nat-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "web" {
  count          = 2
  subnet_id      = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "was" {
  count          = 2
  subnet_id      = aws_subnet.was[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private.id
}



/////// ec2 /////////

data "aws_ami" "al-recent" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-20*-x86_64"]
  }
  owners = ["137112412989"]
}


///// bastion ///////
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
  instance_type = "t3.micro"
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
sleep 30

timedatectl set-timezone Asia/Seoul

EOF

}

output "bastion-publicip" {
  value = aws_instance.bastion.public_ip
}

//////// web //////////
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web sg"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = {
      80 = { protocol = "tcp", sg = aws_security_group.alb.id }
      22 = { protocol = "tcp", sg = aws_security_group.bastion.id }

    }
    content {
      security_groups = [ingress.value.sg]
      from_port       = ingress.key
      to_port         = ingress.key
      protocol        = ingress.value.protocol
      description     = ingress.value.protocol
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }
}


resource "aws_instance" "web" {
  count         = 2
  ami           = data.aws_ami.al-recent.id
  instance_type = "t3.micro"
  key_name      = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id     = aws_subnet.web[count.index].id

  tags = {
    Name = "Web ${local.az_short[count.index]}"
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
sleep 30

timedatectl set-timezone Asia/Seoul
yum -y update
yum install -y httpd
systemctl enable httpd.service

tee -a /etc/httpd/conf/httpd.conf <<END
<VirtualHost *:80>
  ServerName ${aws_lb.alb.dns_name}
  ProxyRequests Off
  ProxyPreserveHost On
  ProxyPass / http://${aws_lb.nlb.dns_name}:8080/
  ProxyPassReverse / http://${aws_lb.nlb.dns_name}:8080/
</VirtualHost>
END

systemctl start httpd.service

EOF

  root_block_device {
    volume_size = 8
  }

}

/// WAS ///

resource "aws_security_group" "was" {
  name        = "was-sg"
  description = "was sg"
  vpc_id      = aws_vpc.vpc.id


  dynamic "ingress" {
    for_each = {
      8080 = { protocol = "tcp", sg = aws_security_group.nlb.id }
      22   = { protocol = "tcp", sg = aws_security_group.bastion.id }

    }
    content {
      security_groups = [ingress.value.sg]
      from_port       = ingress.key
      to_port         = ingress.key
      protocol        = ingress.value.protocol
      description     = ingress.value.protocol
    }
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WAS-SG"
  }
}


resource "aws_instance" "was" {
  count         = 2
  ami           = data.aws_ami.al-recent.id
  instance_type = "t3.large"
  key_name      = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id     = aws_subnet.was[count.index].id

  tags = {
    Name = "WAS ${local.az_short[count.index]}"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.was.id]

  user_data = <<EOF
#!/bin/bash
sleep 30

timedatectl set-timezone Asia/Seoul

dnf update
dnf install java-17-amazon-corretto.x86_64 -y
dnf install git -y

EOF

  root_block_device {
    volume_size = 8
  }
}

/// lb ///
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "alb sg"
  vpc_id      = aws_vpc.vpc.id

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
    Name = "ALB-SG"
  }
}



resource "aws_lb_target_group" "alb" {
  name     = "web-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  health_check {
    path     = "/"
    protocol = "HTTP"
  }
}

resource "aws_lb_target_group_attachment" "alb" {
  count            = 2
  target_group_arn = aws_lb_target_group.alb.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

resource "aws_lb" "alb" {
  name = "web-alb"

  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  // enable_deletion_protection = true
}

resource "aws_lb_listener" "alb" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }
}

resource "aws_security_group" "nlb" {
  name        = "nlb-sg"
  description = "nlb sg"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    security_groups = [aws_security_group.web.id]
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "NLB-SG"
  }
}


resource "aws_lb_target_group" "nlb" {
  name     = "nlb-tg"
  port     = 8080
  protocol = "TCP"
  vpc_id   = aws_vpc.vpc.id
  health_check {
    path     = "/"
    protocol = "HTTP"
  }
}

resource "aws_lb_target_group_attachment" "nlb" {
  count            = 2
  target_group_arn = aws_lb_target_group.nlb.arn
  target_id        = aws_instance.was[count.index].id
  port             = 8080
}

resource "aws_lb" "nlb" {
  name               = "nlb"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb.id]
  subnets            = aws_subnet.was[*].id

  // enable_deletion_protection = true



}

resource "aws_lb_listener" "nlb" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "8080"
  protocol          = "TCP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb.arn
  }
}









/// RDS ///

resource "aws_db_subnet_group" "lab" {
  name       = "lab-db-sbnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name = "lab-db-sbnet-group"
  }
}

resource "aws_db_instance" "db" {
  identifier                 = "rds"
  allocated_storage          = 20
  storage_type               = "gp3"
  db_name                    = "mydb"
  engine                     = "mysql"
  engine_version             = "8.0.39"
  instance_class             = "db.t3.micro"
  username                   = "petclinic"
  password                   = "petclinicPass"
  parameter_group_name       = aws_db_parameter_group.mysql.name
  option_group_name          = aws_db_option_group.mysql.name
  skip_final_snapshot        = true
  apply_immediately          = true
  vpc_security_group_ids     = [aws_security_group.db.id]
  db_subnet_group_name       = aws_db_subnet_group.lab.name
  auto_minor_version_upgrade = false
  multi_az                   = true

}

# resource "aws_db_instance" "lab-replica" {

#    identifier             = "lab-replica"
#    replicate_source_db    = aws_db_instance.lab.identifier
#    instance_class         = "db.t3.micro"
#    apply_immediately      = true

#    skip_final_snapshot    = true
#    vpc_security_group_ids = [aws_security_group.db.id]
#    parameter_group_name =  aws_db_parameter_group.mysql.name
# }


resource "aws_security_group" "db" {
  name        = "rds-sg"
  description = "Database Group Security Groups"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_was" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.was.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}
resource "aws_vpc_security_group_ingress_rule" "db_bastion" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}
resource "aws_vpc_security_group_egress_rule" "db" {
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_db_option_group" "mysql" {
  name                     = "option-group"
  option_group_description = "Terraform Option Group"
  engine_name              = "mysql"
  major_engine_version     = "8.0"
}

resource "aws_db_parameter_group" "mysql" {
  name   = "rds-pg"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "time_zone"
    value = "Asia/Seoul" # 올바른 시간대 이름 사용
  }
}


