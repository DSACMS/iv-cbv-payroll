locals {
  database_config = var.has_database ? {
    region                      = var.default_region
    cluster_name                = "${var.app_name}-${var.environment}"
    app_username                = "app"
    migrator_username           = "migrator"
    schema_name                 = "app"
    app_access_policy_name      = "${var.app_name}-${var.environment}-app-access"
    migrator_access_policy_name = "${var.app_name}-${var.environment}-migrator-access"

    serverless_min_capacity = var.database_serverless_min_capacity
    serverless_max_capacity = var.database_serverless_max_capacity

    # Enable extensions that require the rds_superuser role to be created here
    # See docs/infra/set-up-database.md for more information
    superuser_extensions = {}
  } : null
}
