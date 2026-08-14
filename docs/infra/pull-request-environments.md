# Pull request environments

A temporary environment is created for each pull request that stays up while the pull request is open. The endpoint for the pull request and the deployed commit are added to the pull request description, and updated when the environment is updated. Use cases for the temporary pull request environment includes:

- Allow other delivery stakeholders—including product managers, designers, and business owners—to review changes before being merged and deployed
- Enable automated end-to-end tests on the pull request
- Enable automated accessibility checks on the pull request
- Facilitate workspace creation for developing and testing service layer infrastructure changes

## Lifecycle of pull request environments

Legacy Nava pull request environments are created when a pull request is opened
or reopened, updated when new commits are pushed, and destroyed when the pull
request is merged or closed.

CMS Cloud review apps are created manually from the **CMS Cloud PR Environment
Update** workflow. They reuse the CMS Cloud `dev` network, IAM roles, secrets,
database, cache, identity provider, and storage. Each review app has its own ECS
web service, ALB route, and PostgreSQL schema named for the pull request. The PR
image runs Solid Queue within Puma, so review apps do not create a separate
worker service.

Review apps share the existing CMS Cloud dev ALB. Each app creates only a
target group and a host-header listener rule that forwards its hostname to its
ECS service; it does not provision another load balancer.

The same listener rule forwards agency-specific review hosts such as
`la-pr-123.dev.emmy.cms.gov` and `nh-pr-123.dev.emmy.cms.gov` to that target
group. The review task replaces all agency domain environment variables with
`<agency>-pr-<number>.dev.emmy.cms.gov`, keeping agency links and allowed hosts
inside the review app rather than sending them to the shared dev service.

The CMS Cloud review hostname defaults to
`pr-<number>.dev.emmy.cms.gov`. Public DNS must wildcard `*.dev.emmy.cms.gov`
to the dev ALB. The existing dev certificate's wildcard SAN covers the main
and agency-specific review hostnames.

## Database migrations in review apps

CMS Cloud review apps run the selected commit's migrations inside their
PR-specific schema. The legacy Nava review environments also use isolated
schemas, but their migration behavior may differ from the CMS Cloud workflow.

Schema isolation prevents a review migration from changing the dev schema, but
it does not isolate database-wide operations or SQL that explicitly names
another schema. Review migration code must not create extensions, roles, or
other cluster-level resources.

Application and migration changes can be acceptance-tested together when the
migration stays within the configured schema.

## Implementing pull request environments for each application

Pull request environments are created by GitHub Actions workflows. There are two reusable callable workflows that manage pull request environments:

- [pr-environment-checks.yml](/.github/workflows/pr-environment-checks.yml) - creates or updates a temporary environment in a separate Terraform workspace for a given application and pull request
- [pr-environment-destroy.yml](/.github/workflows/pr-environment-destroy.yml) - destroys a temporary environment and workspace for a given application and pull request

Using these reusable workflows, configure PR environments for each application with application-specific workflows:

- `ci-[app_name]-pr-environment-checks.yml`
  - Based on [ci-app-pr-environment-checks.yml](https://github.com/navapbc/template-infra/blob/main/.github/workflows/ci-%7B%7Bapp_name%7D%7D-pr-environment-checks.yml.jinja)
- `ci-[app_name]-pr-environment-destroy.yml`
  - Based on [ci-app-pr-environment-destroy.yml](https://github.com/navapbc/template-infra/blob/main/.github/workflows/ci-%7B%7Bapp_name%7D%7D-pr-environment-destroy.yml.jinja)
