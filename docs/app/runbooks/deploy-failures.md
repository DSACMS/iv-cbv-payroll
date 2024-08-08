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
2. Check the healthcheck endpoint: https://{host}/health
3. Check the AWS ECS task definition to see what version of the container image is supposed to be used.

## Failed "Build release" step

This action sometimes fails when the Docker rate limit has been reached:

<!-- markdown-link-check-disable -->
> ERROR: failed to solve: registry.docker.com/library/ruby:3.3.0-slim: failed to copy: httpReadSeeker: failed open: unexpected status code https://registry.docker.com/v2/library/ruby/manifests/sha256:{commit sha}: 429 Too Many Requests - Server message: toomanyrequests: You have reached your pull rate limit. You may increase the limit by authenticating and upgrading: https://www.docker.com/increase-rate-limit
<!-- markdown-link-check-enable -->

Docker is likely rate limiting pulling of the Ruby image. This limit resets every 6 hours. Still, Github uses multiple IPs to make egress calls. **Simply redeploying the workflow usually works.** [Further discussion](https://nava.slack.com/archives/C06FC5TPAR3/p1719865408255839?thread_ts=1719862944.272089&cid=C06FC5TPAR3).


## How to change environment variables

1. make sure you are logged into the correct AWS account (look at the account ID in the top right: demo starts with "9", production starts with "7")
2. change the env var value in [Systems Manager > Parameter Store](https://us-east-1.console.aws.amazon.com/systems-manager/parameters/?region=us-east-1&tab=Table)
3. Go to the Elastic Container Service service ([demo](https://us-east-1.console.aws.amazon.com/ecs/v2/clusters/app-dev/services/app-dev/health?region=us-east-1)) > Update Service > check the "Force new deployment" box and keep everything else set the way it is
