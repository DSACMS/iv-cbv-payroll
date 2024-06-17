locals {
  # Map from environment variable name to environment variable value
  # This is a map rather than a list so that variables can be easily
  # overridden per environment using terraform's `merge` function
  default_extra_environment_variables = {
    # Example environment variables
    RAILS_LOG_TO_STDOUT      = "true"
    RAILS_SERVE_STATIC_FILES = "true"

    # Set to true to inform the app that it is running in a container
    DOCKERIZED               = "true"
    # LOG_LEVEL               = "info"
    # DB_CONNECTION_POOL_SIZE = 5
  }

  # Configuration for secrets
  # List of configurations for defining environment variables that pull from SSM parameter
  # store. Configurations are of the format
  # { name = "ENV_VAR_NAME", ssm_param_name = "/ssm/param/name" }
  #
  # Manage the secret values of them using AWS Systems Manager:
  # https://us-east-1.console.aws.amazon.com/systems-manager/parameters/
  secrets = [
    {
      name           = "SECRET_KEY_BASE"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/rails-secret-key-base"
    },
    {
      name           = "RAILS_MASTER_KEY"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/rails-master-key"
    },
    {
      name           = "PINWHEEL_API_TOKEN"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/pinwheel-api-token"
    },
    {
      name           = "CBV_INVITE_SECRET"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/cbv-invite-secret"
    },
  ]
}
