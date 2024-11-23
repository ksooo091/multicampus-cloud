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
  db_name                    = "multi"
  engine                     = "mysql"
  engine_version             = "8.0.39"
  instance_class             = "db.t3.micro"
  username                   = "multi"
  password                   = "multiPass"
  parameter_group_name       = aws_db_parameter_group.mysql.name
  option_group_name          = aws_db_option_group.mysql.name
  skip_final_snapshot        = true
  apply_immediately          = true
  vpc_security_group_ids     = [aws_security_group.db.id]
  db_subnet_group_name       = aws_db_subnet_group.lab.name
  auto_minor_version_upgrade = false
  multi_az                   = true

}



resource "aws_security_group" "db" {
  name        = "rds-sg"
  description = "Database Group Security Groups"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_was" {
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = "192.168.0.0/16"
  # referenced_security_group_id = aws_security_group.was.id
  from_port   = 3306
  ip_protocol = "tcp"
  to_port     = 3306
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
    value = "Asia/Seoul" 
  }
    parameter {
    name  = "max_user_connections"
    value = "100" 
  }
}
