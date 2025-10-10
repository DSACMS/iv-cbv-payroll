# Post-Deployment Checklist

Use this checklist after deploying infrastructure and application to ensure all components are properly configured and functional. This prevents "silent failures" where deployment succeeds but application features don't work.

## ✅ Infrastructure Validation

### Basic Infrastructure
- [ ] **Terraform deployment completed** without errors
- [ ] **ECS service running** with desired task count
- [ ] **Application URL accessible** via browser
- [ ] **Database cluster running** and accessible
- [ ] **ECR repository created** and contains application image

### Network Connectivity
- [ ] **VPC endpoints functional** - ECS tasks can pull images and log to CloudWatch
- [ ] **Security groups configured** - Application can reach database
- [ ] **NAT gateway working** (if `has_external_non_aws_service=true`)
- [ ] **Load balancer healthy** - Target groups show healthy targets

### AWS Service Configuration
- [ ] **CloudWatch logging** - Application logs appear in log groups
- [ ] **Parameter Store accessible** - ECS tasks can read environment variables
- [ ] **Secrets Manager accessible** - Database credentials work
- [ ] **S3 access working** (if application uses S3)

## ✅ Application Configuration

### Rails Framework Setup
- [ ] **SECRET_KEY_BASE configured** in Parameter Store
- [ ] **RAILS_MASTER_KEY configured** and matches local `master.key`
- [ ] **Active Record encryption keys generated** and configured:
  - `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
  - `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
  - `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

### Database Setup
- [ ] **Database migrations completed** successfully
- [ ] **Database extensions enabled** (pgcrypto, etc.) - see [Deployment Failures](deployment-failures.md) if issues
- [ ] **Database users configured** (app, migrator) with proper permissions
- [ ] **Database connectivity verified** from application

### Application Features
- [ ] **Background jobs enabled** - `ACTIVEJOB_ENABLED=true`
- [ ] **Mission Control dashboard accessible** at `/jobs` endpoint
- [ ] **Supported providers configured** - `SUPPORTED_PROVIDERS` set appropriately
- [ ] **Maintenance mode disabled** - `MAINTENANCE_MODE=false`

## ✅ Email Configuration

### SES Setup
- [ ] **Sending domain verified** in SES console
- [ ] **SES production access requested** (if not in sandbox mode)
- [ ] **Test email address verified** for initial testing
- [ ] **Slack test email configured** (demo environments only)

### Email Testing
- [ ] **Send test email** to verified address
- [ ] **Verify delivery** to intended recipient
- [ ] **Check bounce/complaint handling** setup

## ✅ Third-Party Integrations

### Payroll Providers
- [ ] **Argyle credentials configured**:
  - Sandbox: `ARGYLE_API_TOKEN_SANDBOX_ID/SECRET`, `ARGYLE_SANDBOX_WEBHOOK_SECRET`
  - Production: `ARGYLE_API_TOKEN_ID/SECRET`, `ARGYLE_WEBHOOK_SECRET`
- [ ] **Pinwheel credentials configured**:
  - `PINWHEEL_API_TOKEN_DEVELOPMENT/SANDBOX/PRODUCTION`
- [ ] **Provider environments set** per agency requirements

### Monitoring & Analytics
- [ ] **New Relic configured**:
  - `NEWRELIC_API_KEY` valid
  - `NEWRELIC_ENV` set to environment name
  - Metrics appearing in New Relic dashboard
- [ ] **Mixpanel configured**:
  - `MIXPANEL_TOKEN` valid
  - Events being tracked (if applicable)

## ✅ Webhook Configuration (Critical)

**⚠️ Warning:** Application will appear to work but synchronizations will fail without webhook setup.

### Argyle Webhooks
- [ ] **Sandbox webhooks registered** for demo/testing
- [ ] **Production webhooks registered** for live agencies
- [ ] **Webhook delivery verified** in Argyle dashboard

### Pinwheel Webhooks
- [ ] **Demo webhooks registered**
- [ ] **Production webhooks registered**
- [ ] **Webhook delivery verified** in Pinwheel dashboard

## ✅ Multi-Tenant Configuration

### Agency Configuration
- [ ] **Sandbox agency configured** for testing:
  - `SANDBOX_DOMAIN_NAME`, `SANDBOX_ARGYLE_ENVIRONMENT`, `SANDBOX_PINWHEEL_ENVIRONMENT`
  - `AGENCY_DEFAULT_ACTIVE=false` (disabled by default)

- [ ] **Arizona DES agency configured** (if applicable):
  - Domain, SFTP, environment settings
  - `AGENCY_AZ_DES_ACTIVE=true` if enabled
  - Verify partner configuration at [az_des.yml](../../app/config/client-agency-config/az_des.yml)

- [ ] **Louisiana LDH agency configured** (if applicable):
  - Domain, email, pilot status
  - Environment settings
  - Verify partner configuration at [la_ldh.yml](../../app/config/client-agency-config/la_ldh.yml)

### SFTP Configuration (Arizona DES)
- [ ] **SFTP credentials configured** in Parameter Store
- [ ] **SFTP connectivity tested** (if applicable)
- [ ] **SFTP directory permissions verified**

## ✅ API Management (If Needed)

### API User Setup
- [ ] **API user created** for external integrations:
  ```ruby
  user = User.create(email: "api@agency.gov", client_agency_id: "agency_id")
  ```
- [ ] **User promoted to service account**:
  ```bash
  # Demo environment
  rake 'users:promote_to_service_account[user_id]'

  # Production environment
  ./bin/run-command app prod '["./bin/rails", "az_des:create_api_access_token"]'
  ```
- [ ] **API token generated and tested**:
  ```ruby
  token = user.api_access_tokens.create
  puts token.access_token
  ```

### API Testing
- [ ] **Authentication tested** with generated token
- [ ] **Key endpoints verified** (e.g., `/api/v1/invitations`)
- [ ] **API documentation provided** to integration partners

## ✅ Monitoring & Alerting

### Application Health
- [ ] **Health check endpoint** accessible
- [ ] **Application metrics** being collected
- [ ] **Error rate monitoring** configured
- [ ] **Performance monitoring** active

### Database Monitoring
- [ ] **Database connections** monitored
- [ ] **Query performance** tracked
- [ ] **Database capacity** monitored

### Infrastructure Monitoring
- [ ] **ECS service monitoring** configured
- [ ] **Load balancer monitoring** active
- [ ] **Auto-scaling** configured (if applicable)

## ✅ Security Validation

### Access Control
- [ ] **IAM permissions** follow least-privilege principle
- [ ] **Parameter Store access** limited to required services
- [ ] **Database access** properly scoped by user role

### Network Security
- [ ] **Security groups** restrict traffic appropriately
- [ ] **VPC configuration** isolates resources properly
- [ ] **HTTPS enforcement** active on all public endpoints

### Secrets Management
- [ ] **No secrets in environment variables** (use Parameter Store)
- [ ] **Webhook secrets** properly configured and validated
- [ ] **API credentials** secured and rotated regularly

## ✅ End-to-End Testing

### User Flow Testing
- [ ] **Create test invitation** via caseworker flow
- [ ] **Complete applicant flow** using test credentials
- [ ] **Verify payroll connection** and data sync
- [ ] **Check report generation** and delivery
- [ ] **Test agency-specific features** as configured

### Integration Testing
- [ ] **Webhook delivery working** during sync process
- [ ] **Background jobs processing** correctly
- [ ] **Email delivery functional** for reports
- [ ] **Third-party provider integration** working

### Performance Testing
- [ ] **Page load times** acceptable
- [ ] **Database query performance** optimal
- [ ] **Background job processing** timely
- [ ] **Memory and CPU usage** within limits

## ✅ Documentation & Handoff

### Operational Documentation
- [ ] **Environment-specific details** documented
- [ ] **API credentials** shared securely with stakeholders
- [ ] **Monitoring dashboards** configured and accessible
- [ ] **Incident response procedures** established

### Team Knowledge Transfer
- [ ] **Deployment process** documented and understood
- [ ] **Troubleshooting procedures** accessible
- [ ] **Emergency contacts** established
- [ ] **Operational runbooks** created

## 🚨 Critical Failure Points

**Most Common Silent Failures:**
1. **Missing webhook configuration** - Sync process fails
2. **SES in sandbox mode** - Email delivery blocked
3. **Database extension permissions** - Migrations fail
4. **Environment variable configuration** - Features don't work
5. **API credential issues** - Third-party integrations fail

## Emergency Rollback Plan

If critical issues discovered post-deployment:

1. **Application Rollback:**
   ```bash
   TF_CLI_ARGS_apply="-var=image_tag=PREVIOUS_WORKING_TAG" make infra-update-app-service APP_NAME=app ENVIRONMENT=env
   ```

2. **Configuration Rollback:**
   - Revert Parameter Store changes
   - Restore previous webhook configurations
   - Update DNS if domain changes needed

3. **Database Rollback:**
   - Restore from recent backup if schema changes involved
   - Run manual SQL fixes for data issues

## Related Documentation

- [Application Configuration](../app/runbooks/application-configuration.md) - Complete environment variable setup
- [Webhook Configuration](../app/runbooks/webhook-configuration.md) - Required webhook setup
- [Deployment Failures](deployment-failures.md) - Common deployment issues
- [Database Operations](../operations/database-operations.md) - Database management procedures
