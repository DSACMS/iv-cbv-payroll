locals {
  tags = merge(module.project_config.default_tags, {
    network_name = var.network_name
    description  = "VPC resources"
  })
  region = module.project_config.default_region

  network_config = module.project_config.network_configs[var.network_name]
  domain_config  = local.network_config.domain_config

  app_configs = [module.app_config]

  apps_in_network = [
    for app in local.app_configs :
    app
    if anytrue([
      for environment_config in app.environment_configs : true if environment_config.network_name == var.network_name
    ])
  ]

  has_database                 = anytrue([for app in local.apps_in_network : app.has_database])
  has_external_non_aws_service = anytrue([for app in local.apps_in_network : app.has_external_non_aws_service])

  enable_command_execution = anytrue([
    for app in local.apps_in_network :
    anytrue([
      for environment_config in app.environment_configs : true if environment_config.service_config.enable_command_execution == true && environment_config.network_name == var.network_name
    ])
  ])
}

terraform {
  required_version = "~>1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.6.0"
    }
  }

  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {
  region = local.region
  default_tags {
    tags = local.tags
  }
}

module "project_config" {
  source = "../project-config"
}

module "app_config" {
  source = "../app/app-config"
}

module "network" {
  source                                  = "../modules/network"
  name                                    = var.network_name
  aws_services_security_group_name_prefix = module.project_config.aws_services_security_group_name_prefix
  database_subnet_group_name              = local.network_config.database_subnet_group_name
  has_database                            = local.has_database
  has_external_non_aws_service            = local.has_external_non_aws_service
  single_nat_gateway                      = local.network_config.single_nat_gateway
  enable_command_execution                = local.enable_command_execution

  # NEW: pass per-network flags
  az_count            = local.network_config.az_count
  enable_private_ecr  = local.network_config.enable_private_ecr
  enable_db_endpoints = local.network_config.enable_db_endpoints
}

module "domain" {
  source              = "../modules/domain"
  name                = local.domain_config.hosted_zone
  manage_dns          = local.domain_config.manage_dns
  certificate_configs = local.domain_config.certificate_configs
}
