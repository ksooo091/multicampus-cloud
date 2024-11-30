resource "aws_route53_record" "applicant_mcstudy_cname_record" {
  zone_id = aws_route53_zone.mcstudy.id
  name    = "app.${data.hcp_vault_secrets_app.aws_app.secrets.domain}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.was.dns_name]
}




resource "aws_route53_zone" "mcstudy" {
  name = data.hcp_vault_secrets_app.aws_app.secrets.domain
}
resource "aws_acm_certificate" "wildcard_cert" {
  domain_name       = "*.${data.hcp_vault_secrets_app.aws_app.secrets.domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_route53_record" "job_mcstudy_cname_record" {
  zone_id = aws_route53_zone.mcstudy.id
  name    = "job.${data.hcp_vault_secrets_app.aws_app.secrets.domain}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.was.dns_name]
}




resource "aws_route53_record" "admin_mcstudy_cname_record" {
  zone_id = aws_route53_zone.mcstudy.id
  name    = "admin.${data.hcp_vault_secrets_app.aws_app.secrets.domain}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.web.dns_name]
}

resource "aws_route53_record" "zabbix_mcstudy_cname_record" {
  zone_id = aws_route53_zone.mcstudy.id
  name    = "zabbix.${data.hcp_vault_secrets_app.aws_app.secrets.domain}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.web.dns_name]
}

resource "aws_route53_record" "grafana_mcstudy_cname_record" {
  zone_id = aws_route53_zone.mcstudy.id
  name    = "grafana.${data.hcp_vault_secrets_app.aws_app.secrets.domain}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.web.dns_name]
}