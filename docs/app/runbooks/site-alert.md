# Site alert banner

Use `bin/site-alert` during an incident when users need to be told about a
known outage or a problem that may delay a report.

## Prerequisite

Before running the command, authenticate the AWS CLI into the account for the
target environment. The command uses the current AWS identity to update SSM
Parameter Store and restart the web service; it does not select an AWS profile
or assume a role for you.

```
aws sts get-caller-identity
```

Confirm that the returned account is the intended CMS Cloud or Nava account
before enabling or disabling an alert. The AWS CLI region defaults to
`us-east-1`; pass `--region` if the target account uses another region.

## Enable a predefined alert

The predefined message is for scheduled maintenance:

- `scheduled-maintenance` — ReportMyIncome will be unavailable for 30 minutes
  at the scheduled start time.

For Nava environments:

```
bin/site-alert enable --platform nava --environment prod \
  --preset scheduled-maintenance
```

For CMS Cloud environments:

```
bin/site-alert enable --platform cms --environment prod \
  --preset scheduled-maintenance
```

The supported Nava environments are `dev`, `demo`, and `prod`. The supported
CMS Cloud environments are `dev`, `test`, `sandbox`, `demo`, `uat`, and `prod`.
The script updates the English and Spanish title/body parameters, then forces
an ECS rolling deployment so new tasks receive the values. Nava environments
pause for a Terraform checkpoint; CMS Cloud environments do not require one.

## Apply Terraform before Nava deployment

After updating the SSM parameters for Nava, the script prints the command and
waits for the operator to type the completion confirmation.

The Terraform plan may not show changes to environment variables. Continue
with the apply command after reviewing the plan.

For Nava, from the top level of this repository, run:

```
make infra-update-app-service APP_NAME=app ENVIRONMENT=prod
```

Do not type the completion confirmation until the Terraform command finishes
successfully. If the confirmation is not received, the script will not start
an ECS deployment. CMS Cloud skips this Terraform checkpoint and proceeds
directly to deployment.

## Enable a custom alert

Pass all four localized values when the predefined messages do not fit:

```
bin/site-alert enable --platform cms --environment prod \
  --title-en "Service update" \
  --body-en "Please try again later." \
  --title-es "Actualización del servicio" \
  --body-es "Inténtelo de nuevo más tarde." \
  --type warning
```

Alert types are `info`, `success`, `warning`, and `error`. The default is
`warning`. Do not put sensitive or personally identifiable information in a
banner.

## Check or disable the alert

```
bin/site-alert status --platform cms --environment prod
bin/site-alert disable --platform cms --environment prod
```

Disabling only changes `SITE_ALERT_ENABLED`, prompts for the same Terraform
checkpoint, and forces another rolling deployment; it leaves the current copy
in place for the next incident.

By default, enable and disable wait for the ECS service to stabilize. Add
`--no-wait` to return after the deployment starts when the incident requires
the operator to continue immediately. Verify the deployment and alert status
after using that option.
