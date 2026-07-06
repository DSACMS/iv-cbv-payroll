# CI/CD

The CI/CD for this project uses [reusable Github Actions workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows).

## 🧪 CI

### Per app workflows

Each app should have:

- `ci-[app_name]`: must be created; should run linting and testing
- `ci-[app_name]-vulnerability-scans`: calls `vulnerability-scans`
  - Based on [ci-app-vulnerability-scans](https://github.com/navapbc/template-infra/blob/main/.github/workflows/ci-%7B%7Bapp_name%7D%7D-vulnerability-scans.yml.jinja)
- `ci-[app_name]-pr-environment-checks.yml`: calls `pr-environment-checks.yml` to create or update a pull request environment (see [pull request environments](/docs/infra/pull-request-environments.md))
  - Based on [ci-app-pr-environment-checks.yml](https://github.com/navapbc/template-infra/blob/main/.github/workflows/ci-%7B%7Bapp_name%7D%7D-pr-environment-checks.yml.jinja)
- `ci-[app_name]-pr-environment-destroy.yml`: calls `pr-environment-destroy.yml` to destroy the pull request environment (see [pull request environments](/docs/infra/pull-request-environments.md))
  - Based on [ci-app-pr-environment-destroy.yml](https://github.com/navapbc/template-infra/blob/main/.github/workflows/ci-%7B%7Bapp_name%7D%7D-pr-environment-destroy.yml.jinja)

### App-agnostic workflows

- [`ci-docs`](./ci-docs.yml): runs markdown linting on all markdown files in the file
  - Configure in [markdownlint-config.json](./markdownlint-config.json)
- [`ci-infra`](./ci-infra.yml): run infrastructure CI checks

## 🚢 CD

Each app should have:

- `cd-[app_name]`: deploys an application
  - Based on [`cd-app`](https://github.com/navapbc/template-infra/blob/main/.github/workflows/cd-%7B%7Bapp_name%7D%7D.yml.jinja)

The CD workflow uses these reusable workflows:

- [`deploy`](./deploy.yml): deploys an application
- [`database-migrations`](./database-migrations.yml): runs database migrations for an application
- [`build-and-publish`](./build-and-publish.yml): builds a container image for an application and publishes it to an image repository
- [`deploy-cms`](./deploy-cms.yml): builds and publishes a SHA-tagged CMS image, then deploys that same image tag to CMS
- [`deploy-ecs`](./deploy-ecs.yml): updates the CMS ECS `app` and `solid-queue` services to an existing image tag, using `aws-actions/amazon-ecs-render-task-definition` and `aws-actions/amazon-ecs-deploy-task-definition`
- [`build-and-publish-to-cms`](./build-and-publish-to-cms.yml): builds and publishes a SHA-tagged image to the CMS image repository

```mermaid
graph TD
  cd-app
  deploy
  database-migrations
  build-and-publish

  cd-app-->|calls|deploy-->|calls|database-migrations-->|calls|build-and-publish
```

`deploy-cms` builds and deploys a CMS image in one run: it resolves the
requested ref to a commit SHA, publishes that SHA-tagged image if needed, and
then deploys the same SHA tag. It runs automatically on every push to `main`
(deploying to `uat`) and can also be triggered via `workflow_dispatch` to pick a
different environment or ref.

## ⛑️ Helper workflows

- [`check-ci-cd-auth`](./check-ci-cd-auth.yml): verifes that the project's Github repo is able to connect to AWS
