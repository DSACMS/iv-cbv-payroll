# Deploy Failure Runbook

Add documentation to this runbook to help future us diagnose deploy problems.


## Failed "Run Migration" Github Action

This action sometimes fails when "Waiting for log stream to be created". This means the container running migrations failed to start for some reason.

You can see the container startup error by going to the AWS ECS service and changing "Filter Desired Status" to "Any Desired Status":
* https://us-east-1.console.aws.amazon.com/ecs/v2/clusters/app-dev/services/app-dev/tasks?region=us-east-1

<details>
<summary>
<strong>ResourceInitializationError: unable to pull secrets or registry auth</strong>
</summary>
Did you (or someone else) add an environment variable lately? You may need to run `make infra-update-app-service APP_NAME=app ENVIRONMENT=dev` in order for Terraform to give the ECS task executor user permission to pull the value of the environment variable.
</details>

## Unsure what version is deployed?

If you're not sure what version of code is currently deployed, follow these steps to understand the state of the last deploy:

1. Check the latest Github commit and whether it was successfully deployed
2. Check the healthcheck endpoint: https://verify-demo.navapbc.cloud/health
3. Check the AWS ECS task definition to see what version of the container image is supposed to be used.
