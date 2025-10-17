# External Service Prerequisites

Before deploying the CBV Payroll application infrastructure, you will need to set up accounts and obtain credentials for the following external services. These dependencies must be configured before beginning the deployment process.

## Cloud Infrastructure

### AWS (Amazon Web Services)
- **Purpose**: Primary cloud infrastructure provider
- **Required for**: All infrastructure components (compute, storage, networking, database)
- **Setup**: See [Set up AWS account](/docs/infra/set-up-aws-account.md)
- **Website**: https://aws.amazon.com

## Payroll Aggregation Providers

The application requires at least one payroll aggregation provider to be configured. Both providers can be enabled simultaneously for maximum employer coverage.

### Argyle
- **Purpose**: Payroll and employment data aggregation
- **Required for**: Connecting to payroll providers and retrieving employment/income verification data
- **What you need**:
  - Sandbox API credentials (for development/testing)
  - Production API credentials (for production environment)
  - API Key ID and Secret
- **Website**: https://argyle.com/
- **Documentation**: https://docs.argyle.com/

### Pinwheel
- **Purpose**: Payroll and employment data aggregation
- **Required for**: Connecting to payroll providers and retrieving employment/income verification data
- **What you need**:
  - Sandbox API token (for development/testing)
  - Production API token (for production environment)
- **Website**: https://www.pinwheelapi.com/
- **Documentation**: https://docs.pinwheelapi.com/

## Development and Collaboration Tools

### GitHub Team
- **Purpose**: Source code management, CI/CD pipelines, and collaboration
- **Required for**: Version control, pull requests, GitHub Actions workflows
- **What you need**: GitHub Team or Enterprise plan for private repositories
- **Website**: https://github.com/pricing
- **Note**: GitHub Actions are used for automated deployments

### RubyMine (Optional but Recommended)
- **Purpose**: Integrated Development Environment (IDE) for Ruby/Rails development
- **Required for**: Enhanced developer productivity (optional)
- **What you need**: Individual or organizational license
- **Website**: https://www.jetbrains.com/ruby/buy/?section=discounts&billing=yearly
- **Note**: Individual developers may use alternative editors (VS Code, Sublime, etc.)

## Monitoring and Alerting

### New Relic
- **Purpose**: Application Performance Monitoring (APM) and infrastructure observability
- **Required for**: Monitoring application performance, tracking errors, and infrastructure metrics
- **What you need**:
  - Standard license (minimum)
  - License key for APM
  - FedRAMP-compliant endpoints may be required for government deployments
- **Website**: https://newrelic.com/pricing
- **Documentation**: See [Monitoring with New Relic](/README.md#monitoring-with-new-relic)

### Mixpanel
- **Purpose**: Product analytics and user behavior tracking
- **Required for**: Understanding user flows, conversion rates, and product metrics
- **What you need**:
  - Project ID
  - Service Account credentials (username and secret)
- **Website**: https://mixpanel.com/pricing/
- **Documentation**: See [Analytics development](/README.md#for-analytics-development)

### PagerDuty
- **Purpose**: Incident management and on-call alerting
- **Required for**: Real-time alerting for production incidents
- **What you need**:
  - Incident Management plan (minimum)
  - Integration keys for connecting with New Relic and other monitoring tools
- **Website**: https://www.pagerduty.com/pricing/incident-management/
- **Setup**: See [Set up monitoring and alerts](/docs/infra/set-up-monitoring-alerts.md)

## Credential Management

All service credentials should be securely stored and managed. This project uses:

- **AWS Systems Manager Parameter Store** - For environment-specific application configuration
- **1Password** (or similar) - For team credential sharing and backup
- **Rails encrypted credentials** - For application secrets

See [Environment Variables and Secrets](/docs/infra/environment-variables-and-secrets.md) for details on how credentials are managed.

## Cost Considerations

Before proceeding with deployment, review the pricing for each service to understand the total cost of ownership:

- **AWS**: Costs vary based on usage (compute, storage, data transfer, etc.)
- **Argyle/Pinwheel**: Contact vendors for pricing (typically per-connection or per-verification)
- **New Relic**: Standard license starts at ~$100/month per user
- **Mixpanel**: Free tier available; paid plans scale with data volume
- **PagerDuty**: Starts at ~$21/month per user
- **GitHub Team**: ~$4/month per user

## Next Steps

Once you have secured access to the required services:

1. Gather all credentials and store them securely
2. Proceed with [first time initialization](/infra/README.md#1%EF%B8%8F⃣-first-time-initialization)
3. Configure application-specific environment variables as described in [Application Configuration](/docs/app/runbooks/application-configuration.md)
