locals {
  # Map from environment variable name to environment variable value
  # This is a map rather than a list so that variables can be easily
  # overridden per environment using terraform's `merge` function
  default_extra_environment_variables = {
    # Example environment variables
    RAILS_LOG_TO_STDOUT      = "true"
    RAILS_SERVE_STATIC_FILES = "true"

    # Set to true to inform the app that it is running in a container
    DOCKERIZED = "true"
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
      name           = "CBV_INVITE_SECRET"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/cbv-invite-secret"
    },
    {
      name           = "SLACK_TEST_EMAIL"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/slack-test-email"
    },
    {
      name           = "NEWRELIC_KEY"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/newrelic-key"
    },
    {
      name           = "NEW_RELIC_ENV"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/new-relic-env"
    },

    # Transmission Configuration:
    {
      name           = "NYC_HRA_EMAIL"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/nyc-hra-email"
    },

    # Pinwheel Configuration:
    {
      name           = "PINWHEEL_API_TOKEN_PRODUCTION"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/pinwheel-api-token-production"
    },
    {
      name           = "PINWHEEL_API_TOKEN_DEVELOPMENT"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/pinwheel-api-token-development"
    },
    {
      name           = "PINWHEEL_API_TOKEN_SANDBOX"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/pinwheel-api-token-sandbox"
    },
    {
      name           = "NYC_PINWHEEL_ENVIRONMENT"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/nyc-pinwheel-environment"
    },
    {
      name           = "MA_PINWHEEL_ENVIRONMENT"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/ma-pinwheel-environment"
    },
    {
      name           = "SANDBOX_PINWHEEL_ENVIRONMENT"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/sandbox-pinwheel-environment"
    },

    # SSO Configuration:
    {
      name           = "AZURE_NYC_DSS_CLIENT_ID"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/azure-nyc-dss-client-id"
    },
    {
      name           = "AZURE_NYC_DSS_CLIENT_SECRET"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/azure-nyc-dss-client-secret"
    },
    {
      name           = "AZURE_NYC_DSS_TENANT_ID"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/azure-nyc-dss-tenant-id"
    },
    {
      name           = "AZURE_MA_DTA_CLIENT_ID"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/azure-ma-dta-client-id"
    },
    {
      name           = "AZURE_MA_DTA_CLIENT_SECRET"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/azure-ma-dta-client-secret"
    },
    {
      name           = "AZURE_MA_DTA_TENANT_ID"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/azure-ma-dta-tenant-id"
    },
    {
      name           = "AZURE_SANDBOX_CLIENT_ID"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/azure-sandbox-client-id"
    },
    {
      name           = "AZURE_SANDBOX_CLIENT_SECRET"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/azure-sandbox-client-secret"
    },
    {
      name           = "AZURE_SANDBOX_TENANT_ID"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/azure-sandbox-tenant-id"
    },

    # Other site-specific Configuration:
    {
      name           = "MA_DTA_ALLOWED_CASEWORKER_EMAILS"
      ssm_param_name = "/service/${var.app_name}-${var.environment}/ma-dta-allowed-caseworker-emails"
    },
  ]
}
