resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "bastion sg"
  vpc_id      = aws_vpc.vpc.id



  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [format("%s/32", jsondecode(data.http.ipinfo.response_body).ip)]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bastion-SG"
  }
}

resource "aws_security_group" "web-alb" {
  name        = "web-alb-sg"
  description = "web-alb"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "Web-ALB-SG"
  }
}
resource "aws_vpc_security_group_ingress_rule" "web-alb" {
  for_each = {
    http  = 80
    https = 443
    app1  = 8080
    app2  = 3000
  }

  security_group_id = aws_security_group.web-alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "tcp"
}
# resource "aws_vpc_security_group_ingress_rule" "web-alb80" {
#   security_group_id = aws_security_group.web-alb.id
#   cidr_ipv4 = "0.0.0.0/0"
#   from_port         = 80
#   ip_protocol       = "tcp"
#   to_port           = 80
# }

# resource "aws_vpc_security_group_ingress_rule" "web-alb443" {
#   security_group_id = aws_security_group.web-alb.id
#   cidr_ipv4 = "0.0.0.0/0"
#   from_port         = 443
#   ip_protocol       = "tcp"
#   to_port           = 443
# }
# resource "aws_vpc_security_group_ingress_rule" "web-alb8080" {
#   security_group_id = aws_security_group.web-alb.id
#   cidr_ipv4 = "0.0.0.0/0"
#   from_port         = 8080
#   ip_protocol       = "tcp"
#   to_port           = 8080
# }
# resource "aws_vpc_security_group_ingress_rule" "web-alb3000" {
#   security_group_id = aws_security_group.web-alb.id
#   cidr_ipv4 = "0.0.0.0/0"
#   from_port         = 3000
#   ip_protocol       = "tcp"
#   to_port           = 3000
# }


resource "aws_vpc_security_group_egress_rule" "web-alb" {
  security_group_id = aws_security_group.web-alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "web sg"
  vpc_id      = aws_vpc.vpc.id



  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web-alb.id]
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

resource "aws_security_group" "was-alb" {
  name        = "was-alb-sg"
  description = "was-alb"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "WAS-ALB-SG"
  }
}

resource "aws_vpc_security_group_egress_rule" "was-alb" {
  security_group_id = aws_security_group.was-alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "was-alb" {
  for_each = {
    sg_http  = { from_port = 80, to_port = 80, type = "sg" }
    sg_https = { from_port = 443, to_port = 443, type = "sg" }
    ip_http  = { from_port = 80, to_port = 80, type = "ip" }
    ip_https = { from_port = 443, to_port = 443, type = "ip" }
  }

  security_group_id = aws_security_group.was-alb.id

  from_port   = each.value.from_port
  to_port     = each.value.to_port
  ip_protocol = "tcp"

  referenced_security_group_id = each.value.type == "sg" ? aws_security_group.web.id : null
  cidr_ipv4                    = each.value.type == "ip" ? format("%s/32", jsondecode(data.http.ipinfo.response_body).ip) : null
}


# resource "aws_vpc_security_group_ingress_rule" "was-alb80" {
#   security_group_id = aws_security_group.was-alb.id
#   referenced_security_group_id  =  aws_security_group.web.id
#   from_port         = 80
#   ip_protocol       = "tcp"
#   to_port           = 80
# }

# resource "aws_vpc_security_group_ingress_rule" "was-alb443" {
#   security_group_id = aws_security_group.was-alb.id
#   referenced_security_group_id  =  aws_security_group.web.id
#   from_port         = 443
#   ip_protocol       = "tcp"
#   to_port           = 443
# }
# resource "aws_vpc_security_group_ingress_rule" "was-alb80-office" {
#   security_group_id = aws_security_group.was-alb.id
#   cidr_ipv4 = format("%s/32", jsondecode(data.http.ipinfo.response_body).ip)
#   from_port         = 80
#   ip_protocol       = "tcp"
#   to_port           = 80
# }
# resource "aws_vpc_security_group_ingress_rule" "was-alb443-office" {
#   security_group_id = aws_security_group.was-alb.id
#   cidr_ipv4 = format("%s/32", jsondecode(data.http.ipinfo.response_body).ip)
#   from_port         = 443
#   ip_protocol       = "tcp"
#   to_port           = 443
# }


resource "aws_security_group" "was" {
  name        = "was-sg"
  description = "was"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "WAS-SG"
  }
}
resource "aws_vpc_security_group_ingress_rule" "was" {
  for_each = {
    app1 = 8080
    app2 = 8888

  }

  security_group_id            = aws_security_group.was.id
  referenced_security_group_id = aws_security_group.was-alb.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "was" {
  security_group_id = aws_security_group.was.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


resource "aws_security_group" "monitoring" {
  name        = "monitoring-sg"
  description = "monitoring"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "Monitoring-SG"
  }
}

resource "aws_vpc_security_group_egress_rule" "monitoring" {
  security_group_id = aws_security_group.monitoring.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "monitoring" {
  for_each = {
    ssh  = { from_port = 22, to_port = 22 }
    app1 = { from_port = 8080, to_port = 8080 }
    app2 = { from_port = 3000, to_port = 3000 }
  }

  security_group_id = aws_security_group.was-alb.id

  from_port   = each.value.from_port
  to_port     = each.value.to_port
  ip_protocol = "tcp"

  referenced_security_group_id = each.key == "ssh" ? aws_security_group.bastion.id : aws_security_group.web-alb.id

}
