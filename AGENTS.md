# Emmy Repository Guide

## Overview

This repository contains the Eligibility Made Easy (Emmy) web application and
supporting project infrastructure. Emmy is a CMS-maintained tool that helps
states meet Medicaid eligibility requirements and helps beneficiaries complete
eligibility-related tasks more easily.

This repository is organized as a monorepo. Each top-level directory owns a
different part of the system, and more specific instructions may exist inside
subdirectories. When a nested `AGENTS.md` file exists, follow that file for work
inside that subtree.

## Top-Level Structure

- `.github/` - GitHub configuration, issue and pull request templates, CI/CD
  workflows, dependency automation, and repository settings.
- `app/` - The Ruby on Rails application implementing the Emmy web application.
  Read `app/AGENTS.md` before making changes in this directory.
- `bin/` - Scripts for repository-level and infrastructure management tasks.
- `docs/` - Public developer and system documentation.
- `infra/` - Terraform and infrastructure-as-code for Emmy environments.
- `load_testing/` - Load testing resources and related support files.

The Emmy API is maintained separately at
`https://github.com/CMSgov/emmy-api`; do not assume API-only behavior is
implemented in this repository.

## General Working Principles

- Keep changes focused on the requested behavior or documentation update.
- Prefer existing project patterns over introducing new frameworks or
  conventions.
- Read nearby files before editing so the change matches local structure,
  naming, and style.
- Add or update tests whenever the change affects behavior, integration points,
  user flows, data handling, or infrastructure assumptions.
- Run the relevant tests and linters after making changes. Verify they pass
  before considering the task complete.
- Do not commit secrets, credentials, tokens, private keys, production data, or
  generated files that contain sensitive information.
- Avoid broad refactors unless the task explicitly calls for them.

## Rails Application Work

Most product code lives in `app/`. For Rails work, always read and follow
`app/AGENTS.md`.

In short:

- Work from the `app/` directory for Rails commands.
- Application code lives under `app/app/`.
- Configuration lives in `app/config/`.
- Database migrations and schema files live in `app/db/`.
- Tests live in `app/spec/`, with JavaScript tests under `app/spec/javascript`.
- Shared Ruby objects should generally live in `app/services/` or `app/lib/`
  rather than making controllers heavier.

Use the Rails app instructions for command details, coding style, i18n rules,
frontend conventions, and end-to-end test expectations.

## Documentation Work

Public project documentation belongs in `docs/`. Keep documentation plain,
accurate, and easy for new contributors to follow.

When updating docs:

- Prefer links to existing canonical documents instead of duplicating long
  instructions.
- Keep setup, architecture, operations, and policy material in the most specific
  existing document.
- Update the root `README.md` only for high-level project orientation,
  repository navigation, or contributor-facing entry points.

## Infrastructure Work

Infrastructure code lives in `infra/`, with repository-level helper scripts in
`bin/`.

For infrastructure changes:

- Keep Terraform changes tightly scoped.
- Document environment impact, rollout expectations, and any manual steps.
- Include plan/apply notes in the pull request when relevant.
- Be especially careful with changes that affect networking, secrets,
  permissions, queues, storage, or deployed services.

## Testing And Quality

Choose the smallest test set that gives meaningful confidence, then broaden it
when the change affects shared behavior or user-facing flows.

Common expectations:

- Add tests for new logic, endpoints, service objects, jobs, and eligibility or
  payroll edge cases.
- Update E2E coverage when user flows change.
- Run existing tests related to the files you changed.
- Run linters or formatting checks when touching code, templates, styles, or
  JavaScript.
- If a test cannot be run locally, document why and explain what would need to
  run before merge.

## Pull Requests

Follow the repository's contribution guidance in `CONTRIBUTING.md`.

Pull requests should:

- Be small enough to review comfortably.
- Reference the relevant ticket or GitHub issue when available.
- Explain what changed and why.
- Call out migrations, feature flags, infrastructure changes, queue behavior,
  environment variables, monitoring needs, or deployment risk.
- Include acceptance testing notes for user-facing changes.

## Security And Privacy

This project may touch eligibility, income, agency, or beneficiary workflows.
Treat data handling carefully.

- Never add real beneficiary data to tests, fixtures, logs, screenshots, or
  documentation.
- Use synthetic or clearly fake data for examples.
- Do not expose secrets in code, logs, docs, commits, or pull request comments.
- Use local override files such as `.env.local` for developer-specific settings.
- Follow `SECURITY.md` for vulnerability disclosure guidance.

## Before Finishing

Before completing a task, check that:

- The change is scoped to the request.
- Relevant tests, linters, or formatting checks have run or are clearly noted.
- Documentation reflects any behavior, setup, or operational change.
- No secrets or sensitive data were introduced.
- Any remaining risks or follow-up work are called out clearly.