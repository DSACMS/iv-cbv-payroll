resource "aws_route53_record" "app" {
  # Don't create DNS record for temporary environments (e.g. ones spun up by CI/)
  count = !var.is_temporary && var.domain_name != null && var.hosted_zone_id != null ? 1 : 0

  name    = var.domain_name
  zone_id = var.hosted_zone_id
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

# Register additional domains as aliases as well. These must be provided as
# subject_alternative_names to the load balancer certificate as well.
resource "aws_route53_record" "additional_domains" {
  for_each = !var.is_temporary ? toset(var.additional_domains) : toset([])

  name    = each.value
  zone_id = var.hosted_zone_id
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

# Per-PR subdomain (e.g. p-1709.navapbc.cloud) aliased to the PR env's ALB so
# external callers that strictly verify TLS (Pinwheel/Argyle webhook senders)
# can reach the PR env via a hostname the wildcard ACM cert covers. The dev
# env's wildcard A-record for `*.navapbc.cloud` still resolves all other
# subdomains; this specific record takes precedence for its label.
resource "aws_route53_record" "pr_subdomain" {
  count = var.pr_subdomain != null ? 1 : 0

  name    = var.pr_subdomain
  zone_id = var.hosted_zone_id
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}
