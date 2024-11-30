

///////// web ////////


resource "aws_alb" "web" {
  name               = "web-alb"
  subnets            = [aws_subnet.public[0].id, aws_subnet.public[1].id]
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-alb.id]
  internal           = false

}





resource "aws_lb_listener" "web-alb" {
  load_balancer_arn = aws_alb.web.id
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.wildcard_cert.arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener" "web-alb-http" {
  load_balancer_arn = aws_alb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }


}

resource "aws_lb_listener_rule" "web" {
  listener_arn = aws_lb_listener.web-alb.arn
  priority     = 10

  condition {
    host_header {
      values = ["admin.mcstudy.shop"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-alb.arn
  }
}


resource "aws_lb_listener_rule" "grafana" {
  listener_arn = aws_lb_listener.web-alb.arn
  priority     = 20

  condition {
    host_header {
      values = ["grafana.mcstudy.shop"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-3000.arn
  }
}


resource "aws_lb_listener_rule" "zabbix" {
  listener_arn = aws_lb_listener.web-alb.arn
  priority     = 30

  condition {
    host_header {
      values = ["zabbix.mcstudy.shop"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-zabbix.arn
  }
}


resource "aws_lb_target_group" "web-alb" {
  name        = "web-alb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }
}




resource "aws_lb_target_group" "web-zabbix" {
  name        = "zabbix"
  port        = 80
  protocol    = "HTTP"

  vpc_id      = aws_vpc.vpc.id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }
}
resource "aws_lb_target_group" "web-3000" {
  name        = "gf"
  port        = 80
  protocol    = "HTTP"

  vpc_id      = aws_vpc.vpc.id

  health_check {
    path     = "/login"
    protocol = "HTTP"
  }
}


resource "aws_lb_target_group_attachment" "zabbix" {
  target_group_arn = aws_lb_target_group.web-zabbix.arn
  target_id        = aws_instance.monitoring.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "grafana" {
  target_group_arn = aws_lb_target_group.web-3000.arn
  target_id        = aws_instance.monitoring.id
  port             = 3000
}
/////// WAS ///////


resource "aws_alb" "was" {
  name               = "was-alb"
  subnets            = aws_subnet.public[*].id
  load_balancer_type = "application"
  security_groups    = [aws_security_group.was-alb.id]
  internal           = false

}




resource "aws_lb_listener" "was-alb" {
  load_balancer_arn = aws_alb.was.id
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.wildcard_cert.arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener" "was-alb-http" {
  load_balancer_arn = aws_alb.was.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.was-alb.arn
  priority     = 10

  condition {
    host_header {
      values = ["app.mcstudy.shop"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.was-alb-8080.arn
  }
}

resource "aws_lb_listener_rule" "job" {
  listener_arn = aws_lb_listener.was-alb.arn
  priority     = 20

  condition {
    host_header {
      values = ["job.mcstudy.shop"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.was-alb-8888.arn
  }
}





resource "aws_lb_target_group" "was-alb-8080" {
  name        = "was-alb-tg-8080"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }
}

resource "aws_lb_target_group" "was-alb-8888" {
  name        = "was-alb-tg-8888"
  port        = 8888
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }
}
