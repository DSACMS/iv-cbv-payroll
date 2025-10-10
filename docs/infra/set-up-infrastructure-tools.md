# Set up infrastructure developer tools

If you are contributing to infrastructure, you will need to complete these setup steps.

The steps covered in this guide assume you are using MacOS. Alternate package managers and package names are required if you are developing via Linux or Windows WSL.

## Prerequisites

### Install Terraform

[Terraform](https://www.terraform.io/) is an infrastructure as code (IaC) tool that allows you to build, change, and version infrastructure safely and efficiently. This includes both low-level components like compute instances, storage, and networking, as well as high-level components like DNS entries and SaaS features.

You may need different versions of Terraform since different projects may require different versions of Terraform. The best way to manage Terraform versions is with [Terraform Version Manager](https://github.com/tfutils/tfenv).

To install via [Homebrew](https://brew.sh/)

```bash
brew install tfenv
```

Then install the version of Terraform you need.

```bash
tfenv install 1.8.0
```

You may need to set the Terraform version.

```bash
tfenv use 1.8.0
```

### Install AWS CLI

The [AWS Command Line Interface (AWS CLI)](https://aws.amazon.com/cli/) is a unified tool to manage your AWS services. With just one tool to download and configure, you can control multiple AWS services from the command line and automate them through scripts. Install the AWS command line tool by following the instructions found here:

- [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

### Install Go

The [Go programming language](https://go.dev/dl/) is required to run [Terratest](https://terratest.gruntwork.io/), the unit test framework for Terraform.

### Install GitHub CLI

The [GitHub CLI](https://cli.github.com/) is useful for automating certain operations for GitHub such as with GitHub actions. This is needed to run [check-github-actions-auth](/bin/check-github-actions-auth)

```bash
brew install gh
```

### Install linters

We have several optional utilities for running infrastructure linters locally. These are run as part of the CI pipeline, therefore, it is often simpler to test them locally first.

- [Shellcheck](https://github.com/koalaman/shellcheck)
- [actionlint](https://github.com/rhysd/actionlint)
- [markdown-link-check](https://github.com/tcort/markdown-link-check)

```bash
brew install shellcheck
brew install actionlint
make infra-lint
```

## AWS Authentication

For security best practices, we recommend using **AWS SSO (Single Sign-On)** instead of long-lived access keys. SSO provides temporary credentials that automatically rotate, reducing security risks.

### Recommended: AWS SSO Authentication

#### 1. Configure AWS SSO Profile

Set up an SSO profile for your project environment:

```bash
aws configure sso
```

You'll be prompted for:

- **SSO session name**: Choose a descriptive name (e.g., `cbv-project`)
- **SSO start URL**: Your organization's SSO portal URL
- **SSO region**: Region where your SSO is configured (e.g., `us-east-1`)
- **SSO registration scopes**: Leave default (`sso:account:access`)

The CLI will open a browser for you to authenticate via your organization's SSO.

Then configure the AWS profile:

- **CLI default client region**: Your project's primary region (e.g., `us-east-1`)
- **CLI default output format**: `json` (recommended)
- **CLI profile name**: Environment-specific name (e.g., `demo`, `prod`)

#### 2. Verify SSO Authentication

Test your SSO configuration:

```bash
aws sts get-caller-identity --profile demo
```

This should return your user information and assumed role.

#### 3. Use SSO Profiles with Environment Variables

The AWS_PROFILE environment variable is the easiest way to select the right aws profile when interacting with terraform
commands or this project's bin scripts across multiple environments.

Add to your .bashrc file or start each session
```bash
export AWS_PROFILE=demo
```

Or per one-off command:

```bash
AWS_PROFILE=prod terraform -chdir=./infra/networks plan
```

#### 4. Handle SSO Session Expiration

SSO sessions expire periodically. When they do, re-authenticate:

```bash
aws sso login --profile demo
```

### Multiple Environment Setup

For projects with multiple AWS accounts (demo, staging, production):

#### 1. Configure Multiple SSO Profiles

```bash
# Configure demo environment
aws configure sso --profile demo

# Configure production environment
aws configure sso --profile prod
```

#### 3. Switch Between Environments

```bash
# Work with demo environment
export AWS_PROFILE=demo
aws sts get-caller-identity

# Switch to production
export AWS_PROFILE=prod
aws sts get-caller-identity
```

### Troubleshooting Authentication

#### SSO Authentication Issues

**Session expired error:**

```bash
aws sso login --profile demo
```

**Profile not found:**

- Verify profile exists: `aws configure list-profiles`
- Check config file: `cat ~/.aws/config`

#### Terraform Authentication Issues

**Terraform can't find credentials:**

```bash
# Verify AWS CLI works first
aws sts get-caller-identity --profile demo

# Ensure AWS_PROFILE is set
echo $AWS_PROFILE

# Or specify profile for Terraform
export AWS_PROFILE=demo
```

### Security Best Practices

1. **Use SSO whenever possible** - Provides temporary, rotating credentials
2. **Set up MFA** - Enable multi-factor authentication for AWS accounts
3. **Use least-privilege roles** - Only grant necessary permissions
4. **Monitor access** - Review CloudTrail logs for unusual activity
5. **Regular audits** - Review and rotate credentials periodically
6. **Environment separation** - Use different profiles/accounts for different environments

### References

- [AWS CLI SSO Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)
- [AWS SSO User Guide](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html)
- [Security Best Practices for AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-security.html)
- [AWS CLI Environment Variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html)
