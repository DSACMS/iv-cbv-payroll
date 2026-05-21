# Guide to the Emmy Repository Structure

The [`EMMY`](https://github.com/DSACMS/iv-cbv-payroll) repository is a monorepo. The [README](https://github.com/DSACMS/iv-cbv-payroll/blob/main/README.md) identifies the main application as the Rails-based [**Emmy App**](./app/), while the API-only implementation lives in a separate repository.

At the root, start with the main folders:

- `.github/` contains GitHub workflows, issue templates, pull request templates, Dependabot config, and CI/CD support.
- `app/` is the primary Rails application.
- `bin/` contains infrastructure management scripts.
- `docs/` holds public developer documentation, including system architecture, compliance, release, infrastructure, and E2E notes.
- `infra/` contains Terraform and environment replication material.
- `load_testing/` stores load testing resources.

The most important directory is `app/`. Its [app-level guidance](https://github.com/DSACMS/iv-cbv-payroll/blob/main/app/AGENTS.md) describes a conventional Rails layout: application code under `app/app/`, configuration in `app/config/`, migrations in `app/db/`, support code in `app/lib/` and `app/services/`, and tests in `app/spec/`.

Inside `app/app/`, expect the usual Rails neighborhoods: `controllers`, `models`, `views`, `helpers`, `services`, `jobs`, and `javascript`. Business logic should generally live in service objects or library classes so controllers stay thin. Frontend behavior uses Hotwire/Stimulus, with JavaScript bundled into Rails assets.

`app/config/` is where routes, environments, initializers, locales, queue settings, New Relic config, and the client-agency configuration live. That agency config matters because Emmy is designed to support multiple jurisdictions with agency-specific behavior and copy.

`app/spec/` contains RSpec coverage for Ruby code and includes folders for controllers, models, jobs, services, requests, helpers, factories, fixtures, and E2E tests. JavaScript tests live under `spec/javascript` and run with Vitest. The repository guidance emphasizes adding test coverage and running tests after changes.

The dependency files show the platform shape: `app/Gemfile` uses Rails 8, PostgreSQL, Puma, Redis, Solid Queue, Hotwire, Mixpanel, New Relic, AWS libraries, PDF tooling, RSpec, Capybara, Brakeman, RuboCop, and i18n tooling. `app/package.json` adds USWDS, Stimulus, Turbo, esbuild, PostCSS, Sass, Webpack, Prettier, Vite, and Vitest.

For navigation, read the root `README.md`, then `AGENTS.md`, then `app/AGENTS.md`. After that, use `docs/` for architecture and process context, and `app/` for day-to-day implementation.