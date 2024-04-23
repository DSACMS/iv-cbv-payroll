###
# Target space/org
###

data "cloudfoundry_space" "space" {
  org_name = var.cf_org_name
  name     = var.cf_space_name
}

###
# Route mapping and CDN instance
###

data "cloudfoundry_app" "app" {
  name_or_id = "iv_cbv_payroll-${var.env}"
  space      = data.cloudfoundry_space.space.id
}

###########################################################################
# Route must be manually created by an OrgManager before terraform is run:
#
# cf create-domain TKTK-cloud.gov-org-name TKTK-production-domain-name
###########################################################################
data "cloudfoundry_domain" "origin_url" {
  name = var.domain_name
}

resource "cloudfoundry_route" "origin_route" {
  domain = data.cloudfoundry_domain.origin_url.id
  space  = data.cloudfoundry_space.space.id
  target {
    app = data.cloudfoundry_app.app.id
  }
}

data "cloudfoundry_service" "external_domain" {
  name = "external-domain"
}

resource "cloudfoundry_service_instance" "external_domain_instance" {
  name             = "iv_cbv_payroll-domain-${var.env}"
  space            = data.cloudfoundry_space.space.id
  service_plan     = data.cloudfoundry_service.external_domain.service_plans[var.cdn_plan_name]
  recursive_delete = var.recursive_delete
  json_params      = "{\"domains\": \"${var.domain_name}\"}"
}
