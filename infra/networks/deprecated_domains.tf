# #############################################################################
# This file only exists to continue supporting the deprecated domain
# "snap-income-pilot.com" in production.
#
# TODO: Remove this some time after we no longer support this domain name.
#
# Run the following commands to move the preexisting resources into these ones:
#   export AWS_PROFILE=prod
#   terraform -chdir="infra/networks" init -input=false -reconfigure -backend-config="prod.s3.tfbackend"
#   terraform -chdir="infra/networks" state mv 'module.domain.aws_acm_certificate.issued["snap-income-pilot.com"]' 'aws_acm_certificate.deprecated_certificate'
#   terraform -chdir="infra/networks" state mv 'module.domain.aws_route53_zone.zone[0]' 'aws_route53_zone.deprecated_zone'
#   terraform -chdir="infra/networks" state mv 'module.domain.aws_route53_record.validation["snap-income-pilot.com"]' 'aws_route53_record.deprecated_validation'
#
# #############################################################################

resource "aws_acm_certificate" "deprecated_certificate" {
  domain_name       = "snap-income-pilot.com"
  key_algorithm     = "RSA_2048"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_zone" "deprecated_zone" {
  # checkov:skip=CKV2_AWS_38:No need for DNSSEC on this deprecated zone.
  # checkov:skip=CKV2_AWS_39:No need to manage DNS query logging on this deprecated zone.
  name = "snap-income-pilot.com"
}

resource "aws_route53_record" "deprecated_validation" {
  name    = "_68adda3cfec681d22de0bf4e66e946f8.snap-income-pilot.com"
  records = ["_3a86b1ee62e6e99d96fa7ebf4af0dab5.sdgjtdhdhz.acm-validations.aws."]
  ttl     = 60
  type    = "CNAME"
  zone_id = aws_route53_zone.deprecated_zone.id
}
