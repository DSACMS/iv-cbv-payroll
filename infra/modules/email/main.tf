############################################################################################
## A module for setting up SES
## - Creates a verified domain and 0+ verified email accounts
## - Configures DKIM and SPF
## Note: This module assumes that the Route53 hosted zone has been created
############################################################################################
data "aws_region" "current" {}
data "aws_route53_zone" "domain" {
  name         = var.hosted_zone_domain
  private_zone = false
}

resource "aws_sesv2_email_identity" "verified_domain" {
  email_identity = var.domain
  configuration_set_name = aws_ses_configuration_set.require_tls.name
}

resource "aws_ses_email_identity" "verified_emails" {
  for_each = toset(var.verified_emails)
  email    = each.value
}

resource "aws_ses_domain_mail_from" "mail_from" {
  domain           = aws_sesv2_email_identity.verified_domain.email_identity
  mail_from_domain = "mail.${var.domain}"
}

resource "aws_ses_domain_dkim" "ses_domain_dkim" {
  domain = join("", aws_sesv2_email_identity.verified_domain.*.email_identity)
}

resource "aws_route53_record" "amazonses_dkim_record" {
  count   = 3
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "${element(aws_ses_domain_dkim.ses_domain_dkim.dkim_tokens, count.index)}._domainkey.${var.domain}"
  type    = "CNAME"
  ttl     = "1800"
  records = ["${element(aws_ses_domain_dkim.ses_domain_dkim.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource "aws_route53_record" "spf_mail_from" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = aws_ses_domain_mail_from.mail_from.mail_from_domain
  type    = "TXT"
  ttl     = "300"
  records = ["v=spf1 include:amazonses.com ~all"]
} 

resource "aws_route53_record" "mx_domain_record" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = aws_ses_domain_mail_from.mail_from.mail_from_domain
  type    = "MX"
  ttl     = "300"
  records = ["10 feedback-smtp.${data.aws_region.current.name}.amazonses.com"]
}

resource "aws_route53_record" "dmarc_record" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "_dmarc.${var.domain}"
  type    = "TXT"
  ttl     = "300"
  records = ["v=DMARC1; p=none;"]
}

resource "aws_ses_configuration_set" "require_tls" {
  name = "require-tls"

  delivery_options {
    tls_policy = "Require"
  }
}
