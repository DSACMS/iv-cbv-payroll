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
  # Map of configurations for defining environment variables that pull from SSM parameter
  # store. Configurations are of the format
  #
  # {
  #   ENV_VAR_NAME = {
  #     manage_method     = "generated" # or "manual" for a secret that was created and stored in SSM manually
  #     secret_store_name = "/ssm/param/name"
  #   }
  # }
  #
  # Manage the secret values of them using AWS Systems Manager:
  # https://us-east-1.console.aws.amazon.com/systems-manager/parameters/
  secrets = {
    SECRET_KEY_BASE = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/rails-secret-key-base"
    },
    RAILS_MASTER_KEY = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/rails-master-key"
    },
    CBV_INVITE_SECRET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/cbv-invite-secret"
    },
    SLACK_TEST_EMAIL = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/slack-test-email"
    },
    NEWRELIC_KEY = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/newrelic-key"
    },
    NEW_RELIC_ENV = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/new-relic-env"
    },
    MAINTENANCE_MODE = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/maintenance-mode"
    },
    # Transmission Configuration:
    NYC_HRA_EMAIL = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/nyc-hra-email"
    },
    MA_DTA_S3_BUCKET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/ma-dta-s3-bucket"
    },
    MA_DTA_S3_PUBLIC_KEY = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/ma-dta-s3-public-key"
    }

    # Pinwheel Configuration:
    PINWHEEL_API_TOKEN_PRODUCTION = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/pinwheel-api-token-production"
    },
    PINWHEEL_API_TOKEN_DEVELOPMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/pinwheel-api-token-development"
    },
    PINWHEEL_API_TOKEN_SANDBOX = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/pinwheel-api-token-sandbox"
    },
    NYC_PINWHEEL_ENVIRONMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/nyc-pinwheel-environment"
    },
    MA_PINWHEEL_ENVIRONMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/ma-pinwheel-environment"
    },
    SANDBOX_PINWHEEL_ENVIRONMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/sandbox-pinwheel-environment"
    },

    # SSO Configuration:
    AZURE_NYC_DSS_CLIENT_ID = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/azure-nyc-dss-client-id"
    },
    AZURE_NYC_DSS_CLIENT_SECRET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/azure-nyc-dss-client-secret"
    },
    AZURE_NYC_DSS_TENANT_ID = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/azure-nyc-dss-tenant-id"
    },
    AZURE_MA_DTA_CLIENT_ID = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/azure-ma-dta-client-id"
    },
    AZURE_MA_DTA_CLIENT_SECRET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/azure-ma-dta-client-secret"
    },
    AZURE_MA_DTA_TENANT_ID = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/azure-ma-dta-tenant-id"
    },
    AZURE_SANDBOX_CLIENT_ID = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/azure-sandbox-client-id"
    },
    AZURE_SANDBOX_CLIENT_SECRET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/azure-sandbox-client-secret"
    },
    AZURE_SANDBOX_TENANT_ID = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/azure-sandbox-tenant-id"
    },

    # Other site-specific Configuration:
    MA_DTA_ALLOWED_CASEWORKER_EMAILS = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/ma-dta-allowed-caseworker-emails"
    },
    MA_DTA_S3_BUCKET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/ma-dta-s3-bucket"
    },
    MA_DTA_S3_PUBLIC_KEY = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/ma-dta-s3-public-key"
    },
    MA_WEEKLY_REPORT_RECIPIENTS = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/ma-weekly-report-recipients"
    },
  }
}
