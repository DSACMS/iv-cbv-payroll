locals {
  # Map from environment variable name to environment variable value
  # This is a map rather than a list so that variables can be easily
  # overridden per environment using terraform's `merge` function
  default_extra_environment_variables = {
    # Environment variables for all terraform-deployed environments
    RAILS_LOG_TO_STDOUT      = "true"
    RAILS_SERVE_STATIC_FILES = "true"
    RAILS_MAX_THREADS        = 10

    # Set to true to inform the app that it is running in a container
    DOCKERIZED = "true"
    # LOG_LEVEL               = "info"
    # DB_CONNECTION_POOL_SIZE = 5

    # LA LDH pilot configuration
    LA_LDH_PILOT_ENABLED = tostring(var.la_ldh_pilot_enabled)

    DUMMY_VAR_TO_TEST_ACTION = "true"
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
    MISSION_CONTROL_USER = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/mission-control-user"
    },
    MISSION_CONTROL_PASSWORD = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/mission-control-password"
    },
    SLACK_TEST_EMAIL = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/slack-test-email"
    },
    MIXPANEL_TOKEN = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/mixpanel-token"
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
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/active-record-encryption-primary-key"
    },
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/active-record-encryption-deterministic-key"
    },
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/active-record-encryption-key-derivation-salt"
    },


    # Transmission Configuration:
    LA_LDH_EMAIL = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/la-ldh-email"
    },

    # Feature Flags:
    SUPPORTED_PROVIDERS = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/supported-providers"
    },

    ACTIVEJOB_ENABLED = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/activejob-enabled"
    },

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
    AZ_DES_PINWHEEL_ENVIRONMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/az-des-pinwheel-environment"
    },
    LA_LDH_PINWHEEL_ENVIRONMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/la-ldh-pinwheel-environment"
    },
    SANDBOX_PINWHEEL_ENVIRONMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/sandbox-pinwheel-environment"
    },


    # Argyle Configuration:
    AZ_DES_ARGYLE_ENVIRONMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/az-des-argyle-environment"
    },
    LA_LDH_ARGYLE_ENVIRONMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/la-ldh-argyle-environment"
    },
    SANDBOX_ARGYLE_ENVIRONMENT = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/sandbox-argyle-environment"
    },
    ARGYLE_API_TOKEN_SANDBOX_ID = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/argyle-api-token-sandbox-id"
    },
    ARGYLE_API_TOKEN_SANDBOX_SECRET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/argyle-api-token-sandbox-secret"
    },
    ARGYLE_SANDBOX_WEBHOOK_SECRET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/argyle-sandbox-webhook-secret"
    },
    ARGYLE_API_TOKEN_ID = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/argyle-api-token-id"
    },
    ARGYLE_API_TOKEN_SECRET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/argyle-api-token-secret"
    },
    ARGYLE_WEBHOOK_SECRET = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/argyle-webhook-secret"
    },

    # SSO Configuration:
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
    AZ_DES_SFTP_USER = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/az-des-sftp-user"
    },
    AZ_DES_SFTP_PASSWORD = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/az-des-sftp-password"
    },
    AZ_DES_SFTP_URL = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/az-des-sftp-url"
    },
    AZ_DES_SFTP_DIRECTORY = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/az-des-sftp-directory"
    },

    # Other site-specific Configuration:
    LA_LDH_WEEKLY_REPORT_RECIPIENTS = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/la-ldh-weekly-report-recipients"
    },
    AZ_DES_WEEKLY_REPORT_RECIPIENTS = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/az-des-weekly-report-recipients"
    }
    # Domain names
    AZ_DES_DOMAIN_NAME = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/az-des-domain-name"
    },
    LA_LDH_DOMAIN_NAME = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/la-ldh-domain-name"
    },
    SANDBOX_DOMAIN_NAME = {
      manage_method     = "manual"
      secret_store_name = "/service/${var.app_name}-${var.environment}/sandbox-domain-name"
    }
  }
}
