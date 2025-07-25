data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_vpc" "network" {
  tags = {
    project      = module.project_config.project_name
    network_name = local.environment_config.network_name
  }
}

data "aws_subnets" "public" {
  tags = {
    project      = module.project_config.project_name
    network_name = local.environment_config.network_name
    subnet_type  = "public"
  }
}

data "aws_subnets" "private" {
  tags = {
    project      = module.project_config.project_name
    network_name = local.environment_config.network_name
    subnet_type  = "private"
  }
}

locals {
  # The prefix is used to create uniquely named resources per terraform workspace, which
  # are needed in CI/CD for preview environments and tests.
  #
  # To isolate changes during infrastructure development by using manually created
  # terraform workspaces, see: /docs/infra/develop-and-test-infrastructure-in-isolation-using-workspaces.md
  prefix = terraform.workspace == "default" ? "" : "${terraform.workspace}-"

  # Add environment specific tags
  tags = merge(module.project_config.default_tags, {
    environment = var.environment_name
    description = "Application resources created in ${var.environment_name} environment"
  })

  # All non-default terraform workspaces are considered temporary.
  # Temporary environments do not have deletion protection enabled.
  # Examples: pull request preview environments are temporary.
  is_temporary = terraform.workspace != "default"

  build_repository_config                        = module.app_config.build_repository_config
  environment_config                             = module.app_config.environment_configs[var.environment_name]
  service_config                                 = local.environment_config.service_config
  database_config                                = local.environment_config.database_config
  storage_config                                 = local.environment_config.storage_config
  incident_management_service_integration_config = local.environment_config.incident_management_service_integration
  identity_provider_config                       = local.environment_config.identity_provider_config
  notifications_config                           = local.environment_config.notifications_config

  network_config = module.project_config.network_configs[local.environment_config.network_name]

  # Identity provider locals.
  # If this is a temporary environment, re-use an existing Cognito user pool.
  # Otherwise, create a new one.
  identity_provider_user_pool_id = module.app_config.enable_identity_provider ? (
    local.is_temporary ? module.existing_identity_provider[0].user_pool_id : module.identity_provider[0].user_pool_id
  ) : null
  identity_provider_environment_variables = module.app_config.enable_identity_provider ? {
    COGNITO_USER_POOL_ID = local.identity_provider_user_pool_id,
    COGNITO_CLIENT_ID    = module.identity_provider_client[0].client_id
  } : {}
}

terraform {
  required_version = "~>1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.35.0, < 6.0.0"
    }
  }

  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {
  region = local.service_config.region
  default_tags {
    tags = local.tags
  }
}

module "project_config" {
  source = "../../project-config"
}

module "app_config" {
  source = "../app-config"
}

data "aws_rds_cluster" "db_cluster" {
  count              = module.app_config.has_database ? 1 : 0
  cluster_identifier = local.database_config.cluster_name
}

data "aws_iam_policy" "app_db_access_policy" {
  count = module.app_config.has_database ? 1 : 0
  name  = local.database_config.app_access_policy_name
}

data "aws_iam_policy" "migrator_db_access_policy" {
  count = module.app_config.has_database ? 1 : 0
  name  = local.database_config.migrator_access_policy_name
}

resource "aws_iam_policy" "email_access_policy" {
  name        = "${local.service_config.service_name}-email-access"
  description = "Allows the app service to send emails with AWS SES"
  policy      = data.aws_iam_policy_document.email_access_policy.json
}

data "aws_iam_policy_document" "email_access_policy" {
  statement {
    actions = ["ses:SendRawEmail", "ses:SendEmail"]
    resources = [
      "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:identity/*",
      "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:configuration-set/*"
    ]
  }
}

# Retrieve url for external incident management tool (e.g. Pagerduty, Splunk-On-Call)

data "aws_ssm_parameter" "incident_management_service_integration_url" {
  count = module.app_config.has_incident_management_service ? 1 : 0
  name  = local.incident_management_service_integration_config.integration_url_param_name
}

data "aws_security_groups" "aws_services" {
  filter {
    name   = "group-name"
    values = ["${module.project_config.aws_services_security_group_name_prefix}*"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.network.id]
  }
}

data "aws_acm_certificate" "certificate" {
  count  = local.service_config.enable_https ? 1 : 0
  domain = local.service_config.domain_name
}

data "aws_route53_zone" "zone" {
  count = local.service_config.domain_name != null ? 1 : 0
  name  = local.network_config.domain_config.hosted_zone
}

module "service" {
  source       = "../../modules/service"
  service_name = local.service_config.service_name

  image_repository_arn = local.build_repository_config.repository_arn
  image_repository_url = local.build_repository_config.repository_url

  image_tag = local.image_tag

  vpc_id             = data.aws_vpc.network.id
  public_subnet_ids  = data.aws_subnets.public.ids
  private_subnet_ids = data.aws_subnets.private.ids

  domain_name        = local.service_config.domain_name
  hosted_zone_id     = local.service_config.domain_name != null ? data.aws_route53_zone.zone[0].zone_id : null
  certificate_arn    = local.service_config.enable_https ? data.aws_acm_certificate.certificate[0].arn : null
  additional_domains = local.service_config.additional_domains

  cpu                               = local.service_config.cpu
  memory                            = local.service_config.memory
  desired_instance_count            = local.is_temporary ? 1 : local.service_config.desired_instance_count
  solidqueue_desired_instance_count = local.service_config.solidqueue_desired_instance_count
  enable_command_execution          = local.service_config.enable_command_execution

  aws_services_security_group_id = data.aws_security_groups.aws_services.ids[0]

  file_upload_jobs = local.service_config.file_upload_jobs
  scheduled_jobs   = local.environment_config.scheduled_jobs

  db_vars = module.app_config.has_database ? {
    security_group_ids         = data.aws_rds_cluster.db_cluster[0].vpc_security_group_ids
    app_access_policy_arn      = data.aws_iam_policy.app_db_access_policy[0].arn
    migrator_access_policy_arn = data.aws_iam_policy.migrator_db_access_policy[0].arn
    connection_info = {
      host        = data.aws_rds_cluster.db_cluster[0].endpoint
      port        = data.aws_rds_cluster.db_cluster[0].port
      user        = local.database_config.app_username
      db_name     = data.aws_rds_cluster.db_cluster[0].database_name
      schema_name = local.database_config.schema_name
    }
  } : null

  extra_environment_variables = merge(
    {
      FEATURE_FLAGS_PROJECT = module.feature_flags.evidently_project_name
      BUCKET_NAME           = local.storage_config.bucket_name
    },
    local.identity_provider_environment_variables,
    local.service_config.extra_environment_variables
  )

  secrets = concat(
    [for secret_name in keys(local.service_config.secrets) : {
      name      = secret_name
      valueFrom = module.secrets[secret_name].secret_arn
    }],
    module.app_config.enable_identity_provider ? [{
      name      = "COGNITO_CLIENT_SECRET"
      valueFrom = module.identity_provider_client[0].client_secret_arn
    }] : []
  )

  extra_policies = merge(
    {
      feature_flags_access = module.feature_flags.access_policy_arn,
      storage_access       = module.storage.access_policy_arn,
      email_access         = aws_iam_policy.email_access_policy.arn,
    },
    module.app_config.enable_identity_provider ? {
      identity_provider_access = module.identity_provider_client[0].access_policy_arn,
    } : {}
  )

  is_temporary = local.is_temporary
}

module "monitoring" {
  source = "../../modules/monitoring"
  #Email subscription list:
  #email_alerts_subscription_list = ["email1@email.com", "email2@email.com"]

  # Module takes service and ALB names to link all alerts with corresponding targets
  service_name                                = local.service_config.service_name
  load_balancer_arn_suffix                    = module.service.load_balancer_arn_suffix
  incident_management_service_integration_url = module.app_config.has_incident_management_service && !local.is_temporary ? data.aws_ssm_parameter.incident_management_service_integration_url[0].value : null
}

module "feature_flags" {
  source        = "../../modules/feature-flags"
  service_name  = local.service_config.service_name
  feature_flags = module.app_config.feature_flags
}

module "storage" {
  source       = "../../modules/storage"
  name         = local.storage_config.bucket_name
  is_temporary = local.is_temporary
}

module "email" {
  count                       = !local.is_temporary ? 1 : 0
  source                      = "../../modules/email"
  hosted_zone_domain          = local.network_config.domain_config.hosted_zone
  domain                      = local.service_config.domain_name
  newrelic_account_id         = local.environment_config.newrelic_config.account_id
  newrelic_api_key_param_name = "/service/${local.service_config.service_name}/newrelic-key"
}

# If the app has `enable_identity_provider` set to true AND this is not a temporary
# environment, then create a new identity provider.
module "identity_provider" {
  count  = module.app_config.enable_identity_provider && !local.is_temporary ? 1 : 0
  source = "../../modules/identity-provider/resources"

  is_temporary = local.is_temporary

  name                             = local.identity_provider_config.identity_provider_name
  password_minimum_length          = local.identity_provider_config.password_policy.password_minimum_length
  temporary_password_validity_days = local.identity_provider_config.password_policy.temporary_password_validity_days
  verification_email_message       = local.identity_provider_config.verification_email.verification_email_message
  verification_email_subject       = local.identity_provider_config.verification_email.verification_email_subject

  sender_email        = local.notifications_config == null ? null : local.notifications_config.sender_email
  sender_display_name = local.notifications_config == null ? null : local.notifications_config.sender_display_name
  reply_to_email      = local.notifications_config == null ? null : local.notifications_config.reply_to_email
}

# If the app has `enable_identity_provider` set to true AND this *is* a temporary
# environment, then use an existing identity provider.
module "existing_identity_provider" {
  count  = module.app_config.enable_identity_provider && local.is_temporary ? 1 : 0
  source = "../../modules/identity-provider/data"

  name = local.identity_provider_config.identity_provider_name
}

# If the app has `enable_identity_provider` set to true, create a new identity provider
# client for the service. A new client is created for all environments, including
# temporary environments.
module "identity_provider_client" {
  count  = module.app_config.enable_identity_provider ? 1 : 0
  source = "../../modules/identity-provider-client/resources"

  callback_urls = local.identity_provider_config.client.callback_urls
  logout_urls   = local.identity_provider_config.client.logout_urls
  name          = "${local.prefix}${local.identity_provider_config.identity_provider_name}"

  user_pool_id = local.identity_provider_user_pool_id
}
