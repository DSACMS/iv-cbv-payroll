# Full maintenance mode

Use `bin/maintenance-mode` when the entire application needs to be
unavailable. This is separate from the site alert banner and sets the
`MAINTENANCE_MODE` environment variable to `true` or `false`.

## Prerequisite

Authenticate the AWS CLI into the account for the target environment and
confirm the account before changing the setting:

```
aws sts get-caller-identity
```

The AWS region defaults to `us-east-1`; pass `--region` if needed.

## Enable or disable maintenance mode

For Nava:

```
bin/maintenance-mode enable --platform nava --environment prod
bin/maintenance-mode disable --platform nava --environment prod
```

For CMS Cloud:

```
bin/maintenance-mode enable --platform cms --environment prod
bin/maintenance-mode disable --platform cms --environment prod
```

The script updates the platform's SSM parameter, displays the AWS account and
parameter path, and forces an ECS rolling deployment. Terraform is not
required for this setting. The script waits for the ECS service to stabilize
unless `--no-wait` is supplied.

Check the current value with:

```
bin/maintenance-mode status --platform cms --environment prod
```
