locals {
  cf_org_name      = "TKTK-cloud.gov-org-name"
  cf_space_name    = "prod"
  env              = "production"
  recursive_delete = false
}

module "database" {
  source = "../shared/database"

  cf_user          = var.cf_user
  cf_password      = var.cf_password
  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  env              = local.env
  recursive_delete = local.recursive_delete
  rds_plan_name    = "TKTK-production-rds-plan"
}

module "redis" {
  source = "../shared/redis"

  cf_user          = var.cf_user
  cf_password      = var.cf_password
  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  env              = local.env
  recursive_delete = local.recursive_delete
  redis_plan_name  = "TKTK-production-redis-plan"
}



###########################################################################
# The following lines need to be commented out for the initial `terraform apply`
# It can be re-enabled after:
# 1) the app has first been deployed
# 2) the route has been manually created by an OrgManager:
#     `cf create-domain TKTK-cloud.gov-org-name TKTK-production-domain-name`
###########################################################################
# module "domain" {
#   source = "../shared/domain"
#
#   cf_user          = var.cf_user
#   cf_password      = var.cf_password
#   cf_org_name      = local.cf_org_name
#   cf_space_name    = local.cf_space_name
#   env              = local.env
#   recursive_delete = local.recursive_delete
#   cdn_plan_name    = "domain"
#   domain_name      = "TKTK-production-domain-name"
# }
