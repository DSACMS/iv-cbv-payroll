# Application Configuration

This guide covers the complete application-specific configuration required after infrastructure deployment. The CBV application requires 40+ environment variables and secrets that must be manually configured in AWS Systems Manager Parameter Store.

## Overview

Unlike generic infrastructure resources, this Rails application requires extensive configuration for:

- Rails framework secrets and encryption keys
- Multi-tenant client agency settings
- Third-party payroll aggregator integrations
- Email and monitoring service credentials
- Feature flags and operational settings

**Important:** The application will deploy successfully but fail silently without this configuration. Always complete this setup before considering the deployment functional.

## Prerequisites

- Infrastructure deployment completed via Terraform
- AWS CLI configured with appropriate permissions
- Access to AWS Systems Manager Parameter Store
- Rails application running locally for secret generation

## Rails Application Secrets

### Generate Rails Framework Keys

These secrets are required for Rails to function properly. Generate them locally then store in Parameter Store.


| Environment Variable | Parameter Store Key                        | Type         | Description                  | Generation Command                                                        |
| -------------------- | ------------------------------------------ | ------------ | ---------------------------- | ------------------------------------------------------------------------- |
| `SECRET_KEY_BASE`    | `/service/app-{env}/rails-secret-key-base` | SecureString | Rails key generator secret   | `openssl rand -hex 64`                                                    |
| `RAILS_MASTER_KEY`   | `/service/app-{env}/rails-master-key`      | SecureString | Decrypts credentials.yml.enc | Copy from`./app/config/master.key` after running `rails credentials:edit` |

### Generate Active Record Encryption Keys

Rails 7+ requires encryption keys for data protection. Generate these locally:

```bash
cd app/
bin/rails db:encryption:init
```

This outputs three keys to configure:


| Environment Variable                           | Parameter Store Key                                               | Type         |
| ---------------------------------------------- | ----------------------------------------------------------------- | ------------ |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`         | `/service/app-{env}/active-record-encryption-primary-key`         | SecureString |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`   | `/service/app-{env}/active-record-encryption-deterministic-key`   | SecureString |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | `/service/app-{env}/active-record-encryption-key-derivation-salt` | SecureString |

## Application Feature Flags

Configure core application behavior:


| Environment Variable  | Parameter Store Key                      | Type   | Description                                       | Recommended Values                                  |
| --------------------- | ---------------------------------------- | ------ | ------------------------------------------------- |-----------------------------------------------------|
| `ACTIVEJOB_ENABLED`   | `/service/app-{env}/activejob-enabled`   | String | Enable background jobs (analytics, PDFs, reports) | `true` (prod), `true` (demo)                        |
| `SUPPORTED_PROVIDERS` | `/service/app-{env}/supported-providers` | String | Comma-separated payroll aggregators               | `argyle,pinwheel` (prod), `argyle,pinwheel` (demo) |
| `MAINTENANCE_MODE`    | `/service/app-{env}/maintenance-mode`    | String | Show maintenance page                             | `false`                                             |

## Email Configuration

### Test Email Setup (Demo Only)

For demo environments, configure Slack email integration for testing report delivery:


| Environment Variable | Parameter Store Key                   | Type   | Description                  |
| -------------------- | ------------------------------------- | ------ | ---------------------------- |
| `SLACK_TEST_EMAIL`   | `/service/app-{env}/slack-test-email` | String | Slack email for test reports |

**Setup Steps:**

1. Create Slack channel for test emails
2. Generate email address via Slack settings → "Send emails to Slack"
3. Verify email address in AWS SES Console (required for sandbox mode)

## Mission Control Dashboard

Configure access to the background job monitoring dashboard at `/jobs`:


| Environment Variable       | Parameter Store Key                           | Type         | Description        | Value                  |
| -------------------------- | --------------------------------------------- | ------------ | ------------------ | ---------------------- |
| `MISSION_CONTROL_USER`     | `/service/app-{env}/mission-control-user`     | SecureString | Dashboard username | `mission_control`      |
| `MISSION_CONTROL_PASSWORD` | `/service/app-{env}/mission-control-password` | SecureString | Dashboard password | Generated by Terraform |

## Third-Party Service Integrations

### New Relic Monitoring


| Environment Variable | Parameter Store Key                | Type         | Description                           |
| -------------------- | ---------------------------------- | ------------ | ------------------------------------- |
| `NEWRELIC_API_KEY`   | `/service/app-{env}/newrelic-key`  | SecureString | API key from New Relic account        |
| `NEWRELIC_ENV`       | `/service/app-{env}/new-relic-env` | String       | Environment tag (e.g.,`demo`, `prod`) |

### Mixpanel Analytics


| Environment Variable | Parameter Store Key                 | Type         | Description                 |
| -------------------- | ----------------------------------- | ------------ | --------------------------- |
| `MIXPANEL_TOKEN`     | `/service/app-{env}/mixpanel-token` | SecureString | Project token from Mixpanel |

### Argyle Payroll Integration

Configure for both sandbox (testing) and production modes:

Argyel can be used in either "Production" or "Sandbox" mode.  "Production" provides live access to data, while "Sandbox"
mode uses mock users and data to test Argyle's API's.  Sandbox requests are free, but production requests are charged.

| Environment Variable              | Parameter Store Key                                  | Type         | Description               |
| --------------------------------- | ---------------------------------------------------- | ------------ | ------------------------- |
| `ARGYLE_API_TOKEN_SANDBOX_ID`     | `/service/app-{env}/argyle-api-token-sandbox-id`     | SecureString | Sandbox API key           |
| `ARGYLE_API_TOKEN_SANDBOX_SECRET` | `/service/app-{env}/argyle-api-token-sandbox-secret` | SecureString | Sandbox API secret        |
| `ARGYLE_SANDBOX_WEBHOOK_SECRET`   | `/service/app-{env}/argyle-sandbox-webhook-secret`   | SecureString | Sandbox webhook secret    |
| `ARGYLE_API_TOKEN_ID`             | `/service/app-{env}/argyle-api-token-id`             | SecureString | Production API key        |
| `ARGYLE_API_TOKEN_SECRET`         | `/service/app-{env}/argyle-api-token-secret`         | SecureString | Production API secret     |
| `ARGYLE_WEBHOOK_SECRET`           | `/service/app-{env}/argyle-webhook-secret`           | SecureString | Production webhook secret |

### Pinwheel Payroll Integration


| Environment Variable             | Parameter Store Key                                 | Type         | Description           |
| -------------------------------- | --------------------------------------------------- | ------------ | --------------------- |
| `PINWHEEL_API_TOKEN_DEVELOPMENT` | `/service/app-{env}/pinwheel-api-token-development` | SecureString | Development API token |
| `PINWHEEL_API_TOKEN_SANDBOX`     | `/service/app-{env}/pinwheel-api-token-sandbox`     | SecureString | Sandbox API token     |
| `PINWHEEL_API_TOKEN_PRODUCTION`  | `/service/app-{env}/pinwheel-api-token-production`  | SecureString | Production API token  |

## Multi-Tenant Client Agency Configuration

The CBV application serves multiple government agencies. Configure each tenant:

### Sandbox Tenant (Testing)


| Environment Variable           | Parameter Store Key                               | Type   | Value                        |
| ------------------------------ | ------------------------------------------------- | ------ | ---------------------------- |
| `SANDBOX_DOMAIN_NAME`          | `/service/app-{env}/sandbox-domain-name`          | String | Domain for sandbox testing   |
| `SANDBOX_ARGYLE_ENVIRONMENT`   | `/service/app-{env}/sandbox-argyle-environment`   | String | `sandbox` or `production`    |
| `SANDBOX_PINWHEEL_ENVIRONMENT` | `/service/app-{env}/sandbox-pinwheel-environment` | String | `sandbox` or `production`    |
| `AGENCY_DEFAULT_ACTIVE`        | `/service/app-{env}/agency-default-active`        | String | `false` (disable by default) |

### Arizona DES Tenant


| Environment Variable              | Parameter Store Key                                  | Type         | Description                         |
| --------------------------------- | ---------------------------------------------------- | ------------ | ----------------------------------- |
| `AZ_DES_DOMAIN_NAME`              | `/service/app-{env}/az-des-domain-name`              | String       | Agency-specific domain              |
| `AZ_DES_SFTP_USER`                | `/service/app-{env}/az-des-sftp-user`                | SecureString | SFTP username for file transmission |
| `AZ_DES_SFTP_PASSWORD`            | `/service/app-{env}/az-des-sftp-password`            | SecureString | SFTP password                       |
| `AZ_DES_SFTP_URL`                 | `/service/app-{env}/az-des-sftp-url`                 | String       | SFTP server URL                     |
| `AZ_DES_SFTP_DIRECTORY`           | `/service/app-{env}/az-des-sftp-directory`           | String       | Target directory path               |
| `AZ_DES_ARGYLE_ENVIRONMENT`       | `/service/app-{env}/az-des-argyle-environment`       | String       | `sandbox` or `production`           |
| `AZ_DES_PINWHEEL_ENVIRONMENT`     | `/service/app-{env}/az-des-pinwheel-environment`     | String       | `sandbox` or `production`           |
| `AZ_DES_WEEKLY_REPORT_RECIPIENTS` | `/service/app-{env}/az-des-weekly-report-recipients` | String       | Comma-separated email list          |
| `AGENCY_AZ_DES_ACTIVE`            | `/service/app-{env}/agency-az-des-active`            | String       | `true` to enable tenant             |

### PA DHS Tenant

| Environment Variable              | Parameter Store Key                                  | Type         | Description                         |
|-----------------------------------| ---------------------------------------------------- | ------------ | ----------------------------------- |
| `PA_DHS_DOMAIN_NAME`              | `/service/app-{env}/pa-dhs-domain-name`              | String       | Agency-specific domain              |
| `PA_DHS_SFTP_USER`                | `/service/app-{env}/pa-dhs-sftp-user`                | SecureString | SFTP username for file transmission |
| `PA_DHS_SFTP_PASSWORD`            | `/service/app-{env}/pa-dhs-sftp-password`            | SecureString | SFTP password                       |
| `PA_DHS_SFTP_URL`                 | `/service/app-{env}/pa-dhs-sftp-url`                 | String       | SFTP server URL                     |
| `PA_DHS_SFTP_DIRECTORY`           | `/service/app-{env}/pa-dhs-sftp-directory`           | String       | Target directory path               |
| `PA_DHS_ARGYLE_ENVIRONMENT`       | `/service/app-{env}/pa-dhs-argyle-environment`       | String       | `sandbox` or `production`           |
| `PA_DHS_PINWHEEL_ENVIRONMENT`     | `/service/app-{env}/pa-dhs-pinwheel-environment`     | String       | `sandbox` or `production`           |
| `PA_DHS_WEEKLY_REPORT_RECIPIENTS` | `/service/app-{env}/pa-dhs-weekly-report-recipients` | String       | Comma-separated email list          |
| `AGENCY_PA_DHS_ACTIVE`             | `/service/app-{env}/agency-pa-dhs-active`            | String       | `true` to enable tenant             |


### Louisiana LDH Tenant (Deprecated)

Louisiana LDH is not currently used by this repo, but these environment variables are still necessary to define to properly launch the ECS task.
Use placeholder values to create the Parameter Store keys.

| Environment Variable              | Parameter Store Key                                  | Type   | Description                |
| --------------------------------- | ---------------------------------------------------- | ------ | -------------------------- |
| `LA_LDH_DOMAIN_NAME`              | `/service/app-{env}/la-ldh-domain-name`              | String | Agency-specific domain     |
| `LA_LDH_EMAIL`                    | `/service/app-{env}/la-ldh-email`                    | String | Contact email for agency   |
| `LA_LDH_PILOT_ENABLED`            | `/service/app-{env}/la-ldh-pilot-enabled`            | String | `true` if pilot is active  |
| `LA_LDH_ARGYLE_ENVIRONMENT`       | `/service/app-{env}/la-ldh-argyle-environment`       | String | `sandbox` or `production`  |
| `LA_LDH_PINWHEEL_ENVIRONMENT`     | `/service/app-{env}/la-ldh-pinwheel-environment`     | String | `sandbox` or `production`  |
| `LA_LDH_WEEKLY_REPORT_RECIPIENTS` | `/service/app-{env}/la-ldh-weekly-report-recipients` | String | Comma-separated email list |

### Azure AD Integration (Deprecated)

Azure AD SSO integration is not currently used by this repo, but these environment variables are still necessary to define to properly launch the ECS task.
Use placeholder values to create the Parameter Store keys.

| Environment Variable          | Parameter Store Key                              | Type         |
| ----------------------------- | ------------------------------------------------ | ------------ |
| `AZURE_SANDBOX_CLIENT_ID`     | `/service/app-{env}/azure-sandbox-client-id`     | SecureString |
| `AZURE_SANDBOX_CLIENT_SECRET` | `/service/app-{env}/azure-sandbox-client-secret` | SecureString |
| `AZURE_SANDBOX_TENANT_ID`     | `/service/app-{env}/azure-sandbox-tenant-id`     | SecureString |

## Configuration Process

### 1. Create Parameter Store Entries

Create via AWS CLI or AWS Console to create each parameter:

```bash
# Example: Setting Rails secret key
aws ssm put-parameter \
  --profile cbv-demo \
  --name "/service/app-demo/rails-secret-key-base" \
  --value "$(openssl rand -hex 64)" \
  --type "SecureString" \
  --description "Rails secret key base for demo environment"
```

### 2. Validate Configuration

After configuration, restart the application service to load new environment variables:

```bash
# Force service restart to reload environment variables
make infra-update-app-service APP_NAME=app ENVIRONMENT=demo
```

### 3. Test Application Functionality

Verify critical features work:

- Visit application URL and confirm it loads at `/cbv/entry` to test the sandbox account.
- Test user authentication flows using the [Argyle test user accounts](https://docs.argyle.com/overview/sandbox-testing)
- Check background job processing at `/jobs`
- Verify third-party integrations (if applicable)

## Troubleshooting

### Common Issues

**Application won't start:**

- Check CloudWatch logs for missing environment variable errors

**Background jobs failing:**

- Ensure `ACTIVEJOB_ENABLED=true`
- Check Mission Control dashboard at `/jobs`
- Verify database connectivity

**Third-party integration errors:**

- Validate API credentials in respective service dashboards
- If the user gets stuck at `/synchronizations`, update webhook configuration (see [Webhook Configuration](../webhook-configuration.md))

## Security Considerations

- **Never commit secrets to version control**
- **Use SecureString type for all credentials and API keys**
- **Regular rotate API keys and passwords**
- **Limit Parameter Store access via IAM policies**
- **Monitor CloudTrail for parameter access patterns**

## Next Steps

After completing application configuration:

1. [Configure webhooks for payroll providers](webhook-configuration.md)
2. [Set up email service for production](../email-configuration.md)
3. [Complete post-deployment checklist](../../infra/post-deployment-checklist.md)
