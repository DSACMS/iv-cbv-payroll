# Emmy Repository Guide

## Overview

This repository contains the Eligibility Made Easy (Emmy) web application and
supporting project infrastructure. Emmy is a CMS-maintained tool that helps
states meet Medicaid eligibility requirements and helps beneficiaries complete
eligibility-related tasks more easily.

This is a monorepo: each top-level directory owns a different part of the
system, and more specific guidance lives in nested documents. When a nested
`AGENTS.md` or `README` exists, follow it for work inside that subtree.

The Emmy API is maintained separately at
`https://github.com/CMSgov/emmy-api`; do not assume API-only behavior is
implemented in this repository.

## Top-Level Structure

- `app/` - The Ruby on Rails application. Read [`app/AGENTS.md`](./app/AGENTS.md)
  before making changes here.
- `infra/` - Terraform and environment-replication material.
- `docs/` - Public developer documentation.
- `.github/` - CI/CD workflows and GitHub issue/pull request templates.
- `bin/` - Repository- and infrastructure-management scripts.
- `load_testing/` - Performance and load-testing resources.

For a fuller tour of the layout, see
[`docs/repository-guide.md`](./docs/repository-guide.md).

## Where To Go Next

Keep this file high-level. Detailed setup steps, Rails conventions,
infrastructure runbooks, and process docs belong in the specific documents
below, not here.

- Setting up the project or contributing changes? Start with
  [`CONTRIBUTING.md`](./CONTRIBUTING.md).
- Working in the Rails application? Follow [`app/AGENTS.md`](./app/AGENTS.md).
- Need architecture, compliance, release, or process context? Browse
  [`docs/`](./docs).
- Reporting a vulnerability? See [`SECURITY.md`](./SECURITY.md).

## General Working Expectations

- Keep changes scoped to the requested behavior or documentation update; avoid
  broad refactors unless the task calls for them.
- Follow existing project patterns. Read nearby files before editing so the
  change matches local structure, naming, and style.
- Add or update tests whenever you change behavior, integration points, user
  flows, data handling, or infrastructure assumptions.
- Run the relevant tests, linters, and formatting checks after making changes,
  and verify they pass before considering the task complete.
- Never commit secrets, credentials, tokens, private keys, production data, or
  real beneficiary data. Use synthetic data in examples and keep
  developer-specific settings in local override files such as `.env.local`.

## Pull Requests

Follow the contribution guidance in [`CONTRIBUTING.md`](./CONTRIBUTING.md). In
short, keep pull requests small and reviewable, reference the relevant issue,
explain what changed and why, and call out migrations, feature flags,
infrastructure changes, environment variables, or deployment risk.

## Security And Privacy

Emmy touches eligibility, income, agency, and beneficiary workflows, so handle
data carefully. Keep real data out of code, tests, fixtures, logs, screenshots,
and documentation, use clearly synthetic data for examples, and follow
[`SECURITY.md`](./SECURITY.md) for vulnerability disclosure.
