# Running Emmy Locally

This guide walks a new developer through running a local copy of the
**Emmy App** — the Ruby on Rails web application in this repository. By the end
you'll have the app serving at `http://localhost:3000` and be able to walk
through the applicant and caseworker flows against sandbox data.

> This is a practical quick-start, but fundamentally Emmy is a connector
> between agencies, applicants, and verification data sources. As such 
> you will either need to have access to data services like Argyle, or create
> stubs as needed for those services.

## What you're running

The app is multi-tenant across "client agencies". Locally you'll work with the
`sandbox` (a generic test agency). If you're going to connect with payroll data providers (Pinwheel and Argyle), you'll do so in their
**sandbox** modes — no real beneficiary data is involved.

Most commands below run from the `app/` directory unless noted otherwise.

## Prerequisites

The team develops primarily on macOS; some steps assume it.

1. Install the Xcode command line tools:
   ```bash
   xcode-select --install
   ```
2. Install the Homebrew dependencies from the [`Brewfile`](/Brewfile). From the
   repository root:
   ```bash
   brew bundle
   ```
   This installs, among other things, `rbenv` and `nodenv` (Ruby/Node version
   managers), `postgresql@12`, `redis`, `jq`, `graphviz`, `chromedriver`, and
   `ngrok`.
3. Wire up `rbenv` and `nodenv` in your shell, then restart your terminal:
   ```bash
   echo 'if which nodenv >/dev/null 2>/dev/null; then eval "$(nodenv init -)"; fi' >> ~/.zshrc
   echo 'if which rbenv >/dev/null 2>/dev/null; then eval "$(rbenv init -)"; fi' >> ~/.zshrc
   ```
4. `chromedriver` (needed for integration tests) must be allowed to run:
   ```bash
   xattr -d com.apple.quarantine $(which chromedriver)
   ```
5. If you plan to record E2E tests or receive webhooks, set up `ngrok`:
   sign up at <https://dashboard.ngrok.com/signup>, then
   `ngrok config add-authtoken <your-token>`.

## Install the app

Run these from the `app/` directory:

```bash
cd app

# Install the pinned Ruby and Node versions (read from .ruby-version / .node-version)
rbenv install
nodenv install

# Install Ruby and JavaScript dependencies
bundle install
nodenv rehash
npm install
```

Start PostgreSQL (installed via the Brewfile):

```bash
brew services start postgresql@12
```

## Configure environment variables

Emmy uses the [`dotenv`](https://github.com/bkeepers/dotenv) gem. Committed
defaults live in `app/.env`; your personal secrets and overrides go in
`app/.env.local`, which is git-ignored.

```bash
cd app
cp .env.local.example .env.local
```

Open `.env.local` and fill in the values. The
[`.env.local.example`](/app/.env.local.example) file documents each one; the
essentials for a working local app are the payroll-provider sandbox keys:

| Variable | Where to get it |
| :-- | :-- |
| `PINWHEEL_API_TOKEN_SANDBOX` | Pinwheel Console → API Secret |
| `ARGYLE_API_TOKEN_SANDBOX_ID` | Argyle Console |
| `ARGYLE_API_TOKEN_SANDBOX_SECRET` | Argyle Console |
| `ARGYLE_SANDBOX_WEBHOOK_SECRET` | Generate one: `openssl rand -hex 64` |

Some values (`NEWRELIC_KEY`, `MIXPANEL_TOKEN`, `SLACK_TEST_EMAIL`, and others)
should be obtained from a teammate — they're kept in Nava's 1Password under
**"CBV .env.local Rails Secrets"**. Ask another engineer to share these during
onboarding.

> Never commit real credentials or beneficiary data. Keep developer-specific
> settings in `.env.local` (and `.env.test.local` for the test environment).

## Set up the database

```bash
cd app
bin/rails db:create
bin/rails db:schema:load
```

If you'll be running the RSpec suite, also load the schema into the test
database:

```bash
RAILS_ENV=test bin/rails db:schema:load
```

## Start the server

```bash
cd app
bin/dev
```

`bin/dev` uses [`Procfile.dev`](/app/Procfile.dev) to run everything the app
needs together:

- **web** — the Rails server on port 3000
- **js** / **css** — asset builders in watch mode
- **worker** — the Solid Queue background-job worker
- **ngrok** — a tunnel on port 3000 (used to receive aggregator webhooks)

Visit **<http://localhost:3000>** to confirm the app is up.

## Walk through the app

Once the server is running, you can exercise the full flow with sandbox data
(this mirrors the "Manual Testing" section of
[`CONTRIBUTING.md`](/CONTRIBUTING.md)):

1. Go to <http://localhost:3000/sandbox/sso> and sign in as a caseworker with
   your Nava credentials. (Ask the team to get you set up to log in.)
2. Create an invitation for an applicant. Any email works — nothing is actually
   sent locally.
3. In a terminal, open a Rails console and grab the invitation link:
   ```bash
   cd app
   bin/rails console
   ```
   ```ruby
   CbvFlowInvitation.last.to_url
   ```
4. Open that URL to start acting as an applicant. Search for an employer; when
   you select one, the local page shows fake credentials at the bottom — use
   those to sign in and complete the flow, including the generated PDF.
5. To see the caseworker's version of the report PDF, append
   `?is_caseworker=true` to the `/cbv/summary.pdf` path.
6. To switch which client agency a flow belongs to, from the Rails console:
   ```ruby
   CbvFlow.last.update(client_agency_id: 'la_ldh') # or 'sandbox'
   ```

## Optional: test the outbound JSON API

To exercise the income-report transmission API (see
[`docs/api/income-report.md`](/docs/api/income-report.md)) against a local
reference receiver:

```bash
cd app

# Create an API key for the agency you want to test
bin/rails 'users:create_api_token[agency_id]'

# Run the standalone reference receiver (logs incoming JSON, verifies HMAC signatures)
JSON_API_KEY=$(bin/rails runner "puts User.api_key_for_agency('agency_id')") ruby lib/json_api_receiver.rb
```

Then point the Emmy App at the receiver (running on port 4567) by adding the
`LA_LDH_*` variables shown in the
["JSON API Testing" section of `CONTRIBUTING.md`](/CONTRIBUTING.md) to your
`.env.local`.

## Running tests

From the `app/` directory:

```bash
bundle exec rspec                              # Ruby tests
E2E_RUN_TESTS=1 bundle exec rspec spec/e2e/    # End-to-end tests
bundle exec rubocop                            # Ruby style linter
```

See [`CONTRIBUTING.md`](/CONTRIBUTING.md) and
[`docs/e2e/e2e-checks.md`](/docs/e2e/e2e-checks.md) for the full test and
end-to-end recording workflow.

## Troubleshooting & related docs

- To debug a production-style built image locally, see the
  [Running Built Images Locally runbook](/docs/app/runbooks/running-built-images-locally.md).
- For repository layout and where code lives, see the
  [Repository Guide](/docs/repository-guide.md) and [`AGENTS.md`](/AGENTS.md).
- For the authoritative and most detailed setup instructions, always defer to
  [`CONTRIBUTING.md`](/CONTRIBUTING.md).
