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

data "cloudfoundry_service" "redis" {
  name = "aws-elasticache-redis"
}

resource "cloudfoundry_service_instance" "redis" {
  name             = "iv_cbv_payroll-redis-${var.env}"
  space            = data.cloudfoundry_space.space.id
  service_plan     = data.cloudfoundry_service.redis.service_plans[var.redis_plan_name]
  recursive_delete = var.recursive_delete
}
