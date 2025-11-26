# Overview

This repo is a monorepo structure, with top-level directories containing different types of code for different parts of the system. We currently use two:
* `app` - The Ruby on Rails application implementing the Income Verification as a Service (IVaaS) project. See the section below about the `app` subdirectory.
* `infra` - Terraform code related to building our environments.
* `docs` - Documentation about the system.

# Rails (Ruby) `app` subdirectory

The top-level `app` subdirectory contains a Ruby on Rails application. The instructions below all pertain to operations within that directory.

## Codex Sandbox
Ignore if you are not codex:
- All `bin/rails` commands (and also `bin/rspec`) should be run outside the sandbox.
- All `bin/rails` commands (inculding `bin/rspec`) need to be prefixed with `rbenv exec ruby`.

## Project Structure & Module Organization
- Rails app lives in `app/` (`controllers`, `models`, `views`, `services`, `jobs`) with helpers in `app/helpers` and Stimulus controllers in `app/javascript`.
- Shared POROs belong in `services/` or `lib/` to keep controllers thin.
- Tests are in `spec/` (RSpec) and `spec/javascript` (Vitest); assets/builds sit in `app/assets` and `app/assets/builds`.
- Configuration lives in `config/`, migrations in `db/`, and dev scripts in `bin/` and `Makefile`.

## Build, Test, and Development Commands
When developing on the Rails app, ensure you are always in the `app` subdirectory.
- Initialize: Follow the setup instructions (in the top-level README.md).
- Run app: Run `bin/rails server` for the Rails server, or run `bin/dev` to start all services necessary for local development.
- Database commands: Run `bin/rails db:migrate` to update the schema after creating a migration.
- Run tests: Run `bin/rspec` to run all tests. Pass filenames as arguments to `bin/rspec` to run only those tests.
- Frontend/unit JS uses Vitest (`npm test`) with `happy-dom`/`jsdom`; mock network calls and keep components small.
- I18n: We use Rails i18n. Put all strings in the `config/locales/en.yml`. Omit new strings from non-English locale files. After modifying locale files, run the command `bin/rails i18n-normalize`.

## Coding Style & Naming Conventions
- Ruby: RuboCop (rails-omakase + project overrides) enforces 2-space indents and Rails defaults. Run `make lint` or `./bin/rubocop` before pushing.
- JS/TS: Prettier (`tabWidth: 2`, double quotes, no semicolons, `printWidth: 100`) via `npm run format` or `npm run format:precommit`.
- Tests follow `_spec.rb` / `.test.ts`; favor descriptive, imperative example names. Use snake_case for Ruby, camelCase for JS, kebab-case for Stimulus files.

## Testing Guidelines
- Add coverage for new endpoints, logic, and service objects; exercise eligibility and payroll edge cases.
- Prefer writing controller tests over request specs.
- Make sure to update our Capybara/Selenium end-to-end tests. They are in `spec/e2e`. When running these tests, you have to prefix the command with `E2E_RUN_TESTS=1`.

## Commit & Pull Request Guidelines
- Follow history: brief sentence-case subject with issue/PR reference when available (e.g., `Add timeout page title`).
- If you're following a ticket (e.g. "FFS-1234"), then put it as a prefix (e.g., `FFS-1234: Add timeout page title`).
- Commits can include a brief (2-3 sentence) summary of the solution/context.
- Call out migrations, feature flags, and operational impacts (queues, env vars); link to Jira/GitHub issues and note rollout/monitoring.

## Security & Configuration Tips
- Never commit secrets; Override values in `.env` to `.env.local` when modifying environment variables.
- Run Rails commands locally by default; do not use Docker unless explicitly instructed.
