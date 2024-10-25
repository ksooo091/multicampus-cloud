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


resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Allow HTTP SSH"
  vpc_id      = aws_vpc.lab-vpc.id

     dynamic "ingress" {
    for_each = {
      80 = { protocol = "tcp", cidr = "0.0.0.0/0" }
      22 = { protocol = "tcp", cidr = format("%s/32", jsondecode(data.http.ipinfo.response_body).ip)}

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
    Name = "web-SG"
  }
}


resource "aws_instance" "web" {
  ami                         = data.aws_ami.al-recent.id
  instance_type               = "t3.micro"
  key_name                    = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id                   = aws_subnet.public[1].id

  associate_public_ip_address = true
  tags = {
    Name = "Amazon Linux 2 Web Server c}"
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
dnf update
dnf install httpd php php-mysqlnd php-fpm php-json mariadb105 -y

#Web Service start
systemctl enable --now httpd

#Download web data
cd /var/www/html/
wget https://aws-largeobjects.s3.ap-northeast-2.amazonaws.com/AWS-AcademyACF/lab7-app-php7.zip
unzip lab7-app-php7.zip -d /var/www/html/
chown apache:root /var/www/html/rds.conf.php
EOF

root_block_device {
  volume_size = 8
}

}
output "web-publicip" {
  value = aws_instance.web.public_ip
}
data "aws_ami" "al-recent" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-20*-x86_64"]
  }
owners = ["137112412989"] 
}


/// RDS ///

resource "aws_db_subnet_group" "lab" {
  name       = "lab-db-sbnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "lab-db-sbnet-group"
  }
}

resource "aws_db_instance" "lab" {
  identifier          = "lab"
  allocated_storage    = 20
  storage_type               = "gp3"
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "8.0.39"
  instance_class       = "db.t3.micro"
  username             = "master"
  password             = "master-password"
  parameter_group_name = aws_db_parameter_group.mysql.name
  option_group_name = aws_db_option_group.mysql.name
  skip_final_snapshot  = true
  apply_immediately      = true
   vpc_security_group_ids = [aws_security_group.db.id]
   db_subnet_group_name        = aws_db_subnet_group.lab.name
    auto_minor_version_upgrade  = false       
  multi_az = true
    
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
  vpc_id      = aws_vpc.lab-vpc.id

  tags = {
    Name = "rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db" {
  security_group_id = aws_security_group.db.id
  referenced_security_group_id   = aws_security_group.web.id
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
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

  # option {
  #   option_name = "Timezone"

  #   option_settings {
  #     name  = "TIME_ZONE"
  #     value = "UTC+9"
  #   }
  # }

}

resource "aws_db_parameter_group" "mysql" {
  name   = "rds-pg"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }
}