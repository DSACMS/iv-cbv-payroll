# #############################################################################
# This file only exists to continue supporting the deprecated domain
# "snap-income-pilot.com" in production.
#
# TODO: Remove this some time after we no longer support this domain name.
#
# #############################################################################

data "aws_route53_zone" "deprecated_snapincomepilot" {
  count = var.environment_name == "prod" ? 1 : 0

  name = "snap-income-pilot.com"
}

resource "aws_route53_record" "deprecated_snapincomepilot" {
  # checkov:skip=CKV2_AWS_23:This deprecated DNS entry is intended to not point at a resource.
  count = var.environment_name == "prod" ? 1 : 0

  name    = "snap-income-pilot.com"
  zone_id = data.aws_route53_zone.deprecated_snapincomepilot[count.index].id
  type    = "A"
  alias {
    name                   = data.aws_lb.production_load_balancer.dns_name
    zone_id                = data.aws_lb.production_load_balancer.zone_id
    evaluate_target_health = true
  }
}

# #############################################################################
# We need to add the old TLS certificate for snap-income-pilot.com (which isn't
# managed by terraform) to the load balancer so it can serve traffic to that
# domain.
# #############################################################################
data "aws_lb" "production_load_balancer" {
  arn = "arn:aws:elasticloadbalancing:us-east-1:${data.aws_caller_identity.current.id}:loadbalancer/${module.service.load_balancer_arn_suffix}"
}

data "aws_lb_listener" "alb_listener_https" {
  load_balancer_arn = data.aws_lb.production_load_balancer.arn
  port              = 443
}

data "aws_acm_certificate" "deprecated_certificate" {
  count  = var.environment_name == "prod" ? 1 : 0
  domain = "snap-income-pilot.com"
}

resource "aws_lb_listener_certificate" "deprecated_snapincomepilot" {
  count = var.environment_name == "prod" ? 1 : 0

  listener_arn    = data.aws_lb_listener.alb_listener_https.arn
  certificate_arn = data.aws_acm_certificate.deprecated_certificate[count.index].arn
}
