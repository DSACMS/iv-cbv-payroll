# Webhook Configuration

This guide covers the mandatory webhook configuration required for payroll synchronization functionality. The CBV application **requires** webhooks from both Argyle and Pinwheel to be registered post-deployment for the `/synchronizations` process to function.

## Overview

**Critical:** Webhook registration is a **mandatory post-deployment step**. The application will deploy successfully and appear functional, but payroll synchronization will fail silently without proper webhook configuration.

### Why Webhooks Are Required

- Payroll providers (Argyle/Pinwheel) send async notifications about data sync status
- The `/synchronizations` endpoint depends on receiving these webhook callbacks
- Each environment needs webhooks registered for both sandbox AND production provider modes
- Different client agencies may use different provider environments

### Multi-Environment Webhook Requirements

Each deployed environment requires webhook registration for:
- **Argyle Sandbox** - For testing and demo agencies
- **Argyle Production** - For live agency deployments
- **Pinwheel Sandbox** - For testing and demo agencies
- **Pinwheel Production** - For live agency deployments

## Prerequisites

- Application successfully deployed and accessible
- Environment variables configured in Parameter Store (see [Application Configuration](application-configuration.md))
- Local Rails development environment for running webhook registration commands
- Access to Argyle and Pinwheel webhook secrets in Parameter Store

## Environment-Specific Configuration

### Demo Environment

**URL Pattern:** `https://verify-demo.navapbc.cloud`
**Webhook Naming Prefix:** `demo-argyle-sandbox`, `demo-pinwheel`

### Production Environment

**URL Pattern:** `https://reportmyincome.org`
**Webhook Naming Prefix:** `production-argyle`, `production-pinwheel`

## Argyle Webhook Configuration

### Step 1: Verify Current Webhooks

Before registering new webhooks, check existing configuration to avoid duplicates:

```ruby
# In local Rails console: bin/rails console

# Check webhooks from Argyle's sandbox environment
a = Aggregators::Sdk::ArgyleService.new("sandbox")
puts a.get_webhook_subscriptions

# Check webhooks from Argyle's production environment
a = Aggregators::Sdk::ArgyleService.new("production")
puts a.get_webhook_subscriptions
```

**Expected Output:** Three webhook sets with similar names:
- Base webhook with core events
- Webhook ending in "-partial" with "partially_synced" events
- Webhook ending in "-include-resource" with "accounts.updated" events

### Step 2: Configure Environment Variables

Ensure you have the correct webhook secrets configured locally in `.env.local`:

```bash
# Required for webhook registration - get from AWS Parameter Store
ARGYLE_WEBHOOK_SECRET=<production-webhook-secret>
ARGYLE_SANDBOX_WEBHOOK_SECRET=<sandbox-webhook-secret>
```

### Step 3: Register Argyle Webhooks

#### For Demo Environment

```ruby
# In local Rails console
# Register webhooks for sandbox agency using Argyle sandbox environment
m = ArgyleWebhooksManager.new(agency_id: "sandbox")
m.create_subscriptions_if_necessary("https://verify-demo.navapbc.cloud", "demo-argyle-sandbox")
```

#### For Production Environment

```ruby
# In local Rails console

# For agencies using Argyle production environment
# Ensure SANDBOX_ARGYLE_ENVIRONMENT=production in Parameter Store first
m = ArgyleWebhooksManager.new(agency_id: "sandbox")
m.create_subscriptions_if_necessary("https://reportmyincome.org", "production-argyle")

# For agencies using Argyle sandbox in production (if needed)
# Ensure SANDBOX_ARGYLE_ENVIRONMENT=sandbox in Parameter Store first
m = ArgyleWebhooksManager.new(agency_id: "sandbox")
m.create_subscriptions_if_necessary("https://reportmyincome.org", "production-argyle-sandbox")
```

### Step 4: Webhook Deletion (If Needed)

If you need to update webhook configuration (URL, secret, or events), delete old webhooks first:

```ruby
# Get webhook list first to find IDs
a = Aggregators::Sdk::ArgyleService.new("sandbox")
webhooks = a.get_webhook_subscriptions

# Delete specific webhook by ID
webhooks.each do |webhook|
  if webhook["name"].include?("old-webhook-name")
    a.delete_webhook_subscription(webhook["id"])
  end
end
```

## Pinwheel Webhook Configuration

### Step 1: Register Pinwheel Webhooks

#### For Demo Environment

```ruby
# In local Rails console
m = PinwheelWebhookManager.new
m.create_subscription_if_necessary("https://verify-demo.navapbc.cloud", "DEMO")
```

#### For Production Environment

```ruby
# In local Rails console
# Ensure SANDBOX_PINWHEEL_ENVIRONMENT=production in Parameter Store for production webhooks
m = PinwheelWebhookManager.new
m.create_subscription_if_necessary("https://reportmyincome.org", "production-pinwheel")
```

### Step 2: Verify Pinwheel Configuration

Check Pinwheel dashboard to confirm webhooks are registered with correct URLs and are receiving events.

## Agency-Specific Webhook Configuration

Different client agencies may use different provider environments. Configure based on agency requirements:

### Sandbox Agency (Testing)
- Uses environment specified in `SANDBOX_ARGYLE_ENVIRONMENT`
- Uses environment specified in `SANDBOX_PINWHEEL_ENVIRONMENT`

### Arizona DES Agency
- Uses environment specified in `AZ_DES_ARGYLE_ENVIRONMENT`
- Uses environment specified in `AZ_DES_PINWHEEL_ENVIRONMENT`

### Louisiana LDH Agency
- Uses environment specified in `LA_LDH_ARGYLE_ENVIRONMENT`
- Uses environment specified in `LA_LDH_PINWHEEL_ENVIRONMENT`

## Webhook URL Patterns

Webhooks are delivered to standard endpoints:

| Provider | Endpoint Path | Full URL Example                          |
|----------|---------------|-------------------------------------------|
| Argyle | `/webhooks/argyle` | `https://verify-demo.navapbc.cloud/webhooks/argyle`   |
| Pinwheel | `/webhooks/pinwheel` | `https://verify-demo.navapbc.cloud/webhooks/pinwheel` |

## Troubleshooting

### Synchronization Process Failures

**Symptom:** `/synchronizations` endpoint fails or payroll data sync doesn't work

**Diagnosis Steps:**
1. Check webhook registration status by logging into Aggregator provider dashboard.
2. Verify webhook secrets match between Parameter Store and provider dashboards
3. Check provider dashboards for webhook delivery failures
4. Review application logs for webhook processing errors

**Common Issues:**

### Provider Dashboard Verification

#### Argyle Console
1. Login to [Argyle developer console](https://console.argyle.com)
2. Navigate to Developers -> Webhooks section
3. Verify webhooks exist for your environment URLs
4. Check delivery status and any failed deliveries

## Security Considerations

### Webhook Secrets

- **Rotate webhook secrets regularly** in both provider dashboards and Parameter Store
- **Use different secrets for each environment** (demo vs production)
- **Verify webhook authenticity** - application validates incoming webhook signatures
- **Monitor webhook delivery failures** - failed deliveries may indicate security issues

### Network Security

- **HTTPS only** - All webhook URLs must use HTTPS
- **IP whitelisting** - Consider restricting webhook traffic to provider IP ranges if supported
- **Rate limiting** - Monitor for unusual webhook traffic patterns

## Validation Testing

### Test Webhook Delivery

After registration, validate webhooks are working:

1. **Trigger a test sync** in the application by starting a CBV flow and connecting an employer via Argyle.
2. **Monitor provider dashboards** for webhook delivery attempts
3. **Check application logs and webhook_events db table** for webhook receipt and processing.
4. **Verify synchronization completion** in the application.  This might take 30 seconds-2 minutes, even in demo with sandbox mode set.

## Related Documentation

- [Application Configuration](application-configuration.md) - Environment variables required for webhook processing
- [Database Operations](../operations/database-operations.md) - Monitoring webhook delivery via database queries
- [Troubleshooting Application Issues](../troubleshooting/application-issues.md) - Debugging sync failures
