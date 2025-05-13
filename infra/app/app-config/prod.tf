module "prod_config" {
  source                          = "./env-config"
  project_name                    = local.project_name
  app_name                        = local.app_name
  default_region                  = module.project_config.default_region
  environment                     = "prod"
  network_name                    = "prod"
  domain_name                     = "reportmyincome.org"
  enable_https                    = true
  has_database                    = local.has_database
  has_incident_management_service = local.has_incident_management_service
  enable_identity_provider        = local.enable_identity_provider

  database_serverless_min_capacity = 5.0
  database_serverless_max_capacity = 10.0

  # These numbers are a starting point based on this article
  # Update the desired instance size and counts based on the project's specific needs
  # https://conchchow.medium.com/aws-ecs-fargate-compute-capacity-planning-a5025cb40bd0
  service_cpu                    = 1024
  service_memory                 = 4096
  service_desired_instance_count = 10

  # Create DNS records for these `additional_domains` in the default hosted
  # zone (this is necessary to support CBV agency subdomains).
  additional_domains = ["*.reportmyincome.org"]

  # Enables ECS Exec access for debugging or jump access.
  # Defaults to `false`. Uncomment the next line to enable.
  # ⚠️ Warning! It is not recommended to enable this in a production environment.
  # enable_command_execution = true

  # NewRelic configuration for metrics
  newrelic_account_id = "4619676"
}
