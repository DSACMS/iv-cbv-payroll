module "dev_config" {
  source                          = "./env-config"
  project_name                    = local.project_name
  app_name                        = local.app_name
  default_region                  = module.project_config.default_region
  environment                     = "dev"
  network_name                    = "dev"
  domain_name                     = "verify-demo.navapbc.cloud"
  enable_https                    = true
  has_database                    = local.has_database
  has_incident_management_service = local.has_incident_management_service

  # These numbers are a starting point based on this article
  # Update the desired instance size and counts based on the project's specific needs
  # https://conchchow.medium.com/aws-ecs-fargate-compute-capacity-planning-a5025cb40bd0
  service_cpu                    = 512
  service_memory                 = 2048
  service_desired_instance_count = 1

  # Enable and configure identity provider.
  enable_identity_provider = local.enable_identity_provider

  # Support local development against the dev instance.
  extra_identity_provider_callback_urls = ["http://localhost"]
  extra_identity_provider_logout_urls   = ["http://localhost"]

  # Enables ECS Exec access for debugging or jump access.
  # See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html
  # Defaults to `false`. Uncomment the next line to enable.
  enable_command_execution = true
}
