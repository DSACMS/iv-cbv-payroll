# Site alerts

`ENABLED_ALERTS` is a comma-separated list of alert identifiers. The application
trims surrounding whitespace and matches identifiers exactly. An unset, empty,
or whitespace-only value enables no alerts. Unknown identifiers are ignored.

The `site_alert` identifier displays the generic banner throughout the site.
Its copy continues to come from `SITE_ALERT_TITLE_EN`, `SITE_ALERT_BODY_EN`,
`SITE_ALERT_TITLE_ES`, and `SITE_ALERT_BODY_ES`. `SITE_ALERT_TYPE` controls the
visual severity (`info`, `success`, `warning`, or `error`).

## Managing the generic banner

From the repository root, with AWS credentials for the intended account:

```sh
bin/site-alert enable --platform cms --environment prod --type site_alert \
  --preset scheduled-maintenance --severity warning
bin/site-alert status --platform cms --environment prod
bin/site-alert disable --platform cms --environment prod --type site_alert
```

Use `--platform nava` for Nava environments. Run `bin/site-alert --help` for
supported targets and custom English/Spanish message options. `--type` selects
an alert identifier (currently only `site_alert`); use `--severity` for the
visual severity previously selected with `--type`.

The script preserves other identifiers when enabling or disabling `site_alert`.
It reads the current SSM value, updates SSM, and starts an ECS deployment.
Avoid concurrent alert changes because SSM updates are not atomic list edits.
For Nava, it pauses for the operator to apply Terraform before deployment.
The application reads environment variables when containers start; changes do
not affect already-running containers.

## Deployment configuration

Set the `enabled-alerts` SSM parameter before deploying this application change:

- Nava: `/service/app-ENVIRONMENT/enabled-alerts` (mapped by this repository's
  Terraform).
- CMS: `/emmy/ENVIRONMENT/app/enabled-alerts` (configure the environment variable
  mapping in the CMS infrastructure repository).

If the old generic banner is enabled, initialize the new value to `site_alert`;
otherwise initialize it to one space. SSM cannot store an empty string, so the
script writes a single space when the last alert is disabled. Local development
can use `ENABLED_ALERTS=` or omit the variable entirely.

Apply the infrastructure mapping before starting new containers. The previous
boolean banner flag is no longer read. Existing banner title/body and severity
parameters remain unchanged. For a rollback, restore the previous mapping and
boolean value before deploying the previous application version.
