resource "aws_route53_zone" "mcstudy" {
  name = "mcstudy.shop"
}

resource "aws_route53_record" "applicant_mcstudy_cname_record" {
  zone_id = aws_route53_zone.mcstudy.zone_id
  name    = "app.mcstudy.shop"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.was.dns_name]
}



resource "aws_route53_record" "job_mcstudy_cname_record" {
  zone_id = aws_route53_zone.mcstudy.zone_id
  name    = "job.mcstudy.shop"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.was.dns_name]
}




resource "aws_route53_record" "admin_mcstudy_cname_record" {
  zone_id = aws_route53_zone.mcstudy.zone_id
  name    = "admin.mcstudy.shop"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.web.dns_name]
}



resource "aws_acm_certificate" "wildcard_cert" {
  domain_name       = "*.mcstudy.shop"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

