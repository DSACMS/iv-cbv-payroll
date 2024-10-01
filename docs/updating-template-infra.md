# Upgrading the template-infra repo

When there are new versions of the template-infra code that we want to use, we'll need to upgrade to it.

On CBV, we have our own [upgrade script][1] which steps through every commit in the template-infra repo and applies it to our repository. The difficulty comes in processing the merge conflicts.

## Starting the upgrade
1. Figure out our current version of the template-infra code by looking at the `.template-version` file
2. Read the template-infra release notes for any versions between the current version and the version we're upgrading to
3. Run the upgrade script with `bin/update-infra-template [version]` for the version to upgrade to (recommended: upgrade only one version at a time)
4. After completing the upgrade script, you'll probably want to squash all the commits into a single upgrade commit.


## Checking the upgrade
Before merging the upgrade, verify that the following commands work (make sure to cancel out before they do anything, until you want to actually upgrade):
* `make infra-update-current-account`
* `AWS_PROFILE=prod make infra-update-app-build-repository APP_NAME=app`
* `make infra-update-app-database APP_NAME=app ENVIRONMENT=dev`
* `make infra-update-network NETWORK_NAME=dev`
* `make infra-update-app-service APP_NAME=app ENVIRONMENT=dev`


## Performing the upgrade
1. Tell the Eng Team not to merge anything
2. Run the above commands locally, allowing them to apply their changes
3. Merge the commit with the upgrade(s)
4. Do smoke testing in lower environments
5. Deploy to production by running the above commands but with `ENVIRONMENT=prod` and with the correct AWS credentials (i.e. prefix the commands with `AWS_PROFILE=prod`)

[1]: https://github.com/DSACMS/iv-cbv-payroll/pull/275/commits/97e7697afab83da5cc030bd2eb885c7d22487493
