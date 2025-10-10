# Deployment Failures Troubleshooting

This guide addresses common deployment failures that occur after successful infrastructure deployment but during application initialization or first deployment.

## Database Migration Failures

### pgcrypto Extension Permission Error

**Symptom:** Database migrations fail with permission errors related to the `pgcrypto` extension, typically during the first application deployment after infrastructure setup.

**Root Cause:** The automated database role setup doesn't always grant sufficient privileges for Rails migrations that require database extensions.

**Solution:** Manual intervention using AWS RDS Query Editor with postgres superuser privileges.

#### Step 1: Access AWS RDS Query Editor

1. Navigate to AWS RDS Console
2. Select your database cluster
3. Click "Query Editor"
4. Choose "Connect with Secrets Manager"
5. Find the Secrets Manager ARN from AWS Systems Manager Parameter Store or 1Password
6. This logs you in as the `postgres` superuser

#### Step 2: Run Extension Setup Script

Execute the following SQL commands to resolve pgcrypto permissions:

```sql
-- Enable pgcrypto extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Grant usage on the extension to the app and migrator users
GRANT USAGE ON SCHEMA public TO app;
GRANT USAGE ON SCHEMA public TO migrator;

-- Ensure proper permissions on the app schema
GRANT ALL PRIVILEGES ON SCHEMA app TO migrator;
GRANT USAGE ON SCHEMA app TO app;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON TABLES TO app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON SEQUENCES TO app;
```

#### Step 3: Retry Migration

After running the manual setup, retry the application deployment:

```bash
# Restart the application service to retry migrations
make infra-update-app-service APP_NAME=app ENVIRONMENT=demo
```

#### Step 4: Verify Migration Success

Check the application logs in CloudWatch to confirm migrations completed successfully.

## Application Startup Failures

### Missing Environment Variables

**Symptom:** Application starts but returns 500 errors, or ECS tasks fail to start.

**Root Cause:** Required environment variables not configured in Parameter Store.

**Resolution:**
1. Check CloudWatch logs for specific missing variables
2. Review [Application Configuration](../app/runbooks/application-configuration.md) for complete variable list
3. Add missing parameters to AWS Systems Manager Parameter Store
4. Restart application service

### Rails Credentials Decryption Failure

**Symptom:** Application fails to start with errors about credentials decryption.

**Root Cause:** `RAILS_MASTER_KEY` not properly configured or doesn't match the encrypted credentials file.

**Resolution:**
1. Verify `RAILS_MASTER_KEY` in Parameter Store matches `app/config/master.key`
2. If key is missing, generate new credentials:
   ```bash
   cd app/
   rm config/credentials.yml.enc  # Remove old encrypted file
   rails credentials:edit         # Creates new key and file
   ```
3. Update Parameter Store with new master key
4. Commit new `credentials.yml.enc` file (but never commit `master.key`)

## Network Connectivity Issues

### Database Connectivity

**Symptom:** Application starts but cannot connect to database.

**Root Cause:** Security groups, network ACLs, or database configuration issues.

**Diagnosis:**
1. Check application logs for database connection errors
2. Verify database security group allows traffic from ECS security group
3. Confirm database is running and accessible

**Resolution:**
1. Update security group rules if needed
2. Verify database endpoint configuration in Parameter Store
3. Test connectivity from ECS task:
   ```bash
   # Use ECS exec to test database connectivity
   ./bin/ecs-console app demo
   # In Rails console:
   ActiveRecord::Base.connection.execute("SELECT 1")
   ```

## GitHub Actions CI/CD Failures

### AWS Authentication Issues

**Symptom:** GitHub Actions fail with AWS authentication errors.

**Diagnosis:**
1. Verify GitHub OIDC provider is configured in AWS
2. Check IAM role trust policy allows GitHub repository
3. Confirm GitHub repository secrets are configured

**Resolution:**
1. Re-run account setup if OIDC provider is missing:
   ```bash
   make infra-set-up-account ACCOUNT_NAME=demo
   ```
2. Verify GitHub Actions authentication:
   ```bash
   make infra-check-github-actions-auth ACCOUNT_NAME=demo
   ```

### Build/Deploy Pipeline Failures

**Symptom:** Application builds but deployment fails.

**Common Causes:**
1. Image tag mismatch between build and deploy steps
2. ECS service update failures
3. Database migration errors during deployment

**Resolution:**
1. Check GitHub Actions logs for specific error details
2. Verify image was successfully pushed to ECR
3. Review ECS service events in AWS Console
4. Check application logs for migration or startup errors

## Related Documentation

- [Application Configuration](../app/runbooks/application-configuration.md) - Complete environment variable setup
- [Database Operations](../operations/database-operations.md) - Advanced database troubleshooting
- [AWS Service Issues](./aws-service-issues.md) - AWS-specific service problems
