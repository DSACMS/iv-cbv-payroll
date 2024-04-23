###
# Target space/org
###

data "cloudfoundry_space" "space" {
  org_name = var.cf_org_name
  name     = var.cf_space_name
}

###
# RDS instance
###

data "cloudfoundry_service" "rds" {
  name = "aws-rds"
}

resource "cloudfoundry_service_instance" "rds" {
  name             = "iv_cbv_payroll-rds-${var.env}"
  space            = data.cloudfoundry_space.space.id
  service_plan     = data.cloudfoundry_service.rds.service_plans[var.rds_plan_name]
  recursive_delete = var.recursive_delete
}
