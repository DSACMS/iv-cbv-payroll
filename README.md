Income Verification: Consent-Based Verification (Payroll)
========================

<<TKTK: quick summary of project>>

## Development

If you're new to Rails, see the [Getting Started with Rails](https://guides.rubyonrails.org/getting_started.html)
guide for an introduction to the framework.

### Local Setup

* All of these steps need to be run within the `cbv` directory
* Install Xcode Command Line Tools
* Install homebrew dependencies: `brew bundle`
  * rbenv
  * nodenv
  * [redis]()
  * [jq](https://stedolan.github.io/jq/)
  * [PostgreSQL](https://www.postgresql.org/)
  * [Dockerize](https://github.com/jwilder/dockerize)
  * [ADR Tools](https://github.com/npryce/adr-tools)
  * [Graphviz](https://voormedia.github.io/rails-erd/install.html): brew install graphviz
  * [Chromedriver](https://sites.google.com/chromium.org/driver/)
    * Chromedriver must be allowed to run. You can either do that by:
      * The command line: `xattr -d com.apple.quarantine $(which chromedriver)` (this is the only option if you are on Big Sur)
      * Manually: clicking "allow" when you run the integration tests for the first time and a dialogue opens up
  * [Ngrok](https://ngrok.com/download): brew install ngrok/ngrok/ngrok
    * Sign up for an account: https://dashboard.ngrok.com/signup
    * run `ngrok config add-authtoken {token goes here}`
* Set up rbenv and nodenv:
  * `echo 'if which nodenv >/dev/null 2>/dev/null; then eval "$(nodenv init -)"; fi' >> ~/.zshrc`
  * `echo 'if which rbenv >/dev/null 2>/dev/null; then eval "$(rbenv init -)"; fi' >> ~/.zshrc`
  * Close & re-open your terminal
* Install Ruby: `rbenv install`
* Install NodeJS `nodenv install`
* Install Ruby dependencies: `bundle install`
* Install JS dependencies
  * `npm install -g yarn`
  * `nodenv rehash`
  * `yarn install`
* Start postgres & redis:
  * `brew services start postgresql@12`
  * `brew services start redis`
* Create database: `bin/rails db:create`
* Run migrations: `bin/rails db:migrate`
* Run the development server: `bin/dev`
* Visit the site: http://localhost:3000

### Local Configuration

Environment variables can be set in development using the [dotenv](https://github.com/bkeepers/dotenv) gem.

Consistent but sensitive credentials should be added to `config/credentials.yml.enc` by using `$ rails credentials:edit`

Production credentials should be added to `config/credentials/production.yml.enc` by using `$ rails credentials:edit --environment production`

Any changes to variables in `.env` that should not be checked into git should be set in `.env.local`.

If you wish to override a config globally for the `test` Rails environment you can set it in `.env.test.local`.
However, any config that should be set on other machines should either go into `.env` or be explicitly set as part
of the test.

To run locally, use `bin/dev`

### Deploy / Infrastructure Configuration
1. Get an AWS account and configure your IAM credentials via `aws configure`
2. `make infra-set-up-account ACCOUNT_NAME="nava-cbv-dev"`

After making changes to cbv code, build a new Docker image via (in `cbv` directory):
`docker build --platform linux/amd64 --tag iv-cbv-payroll-cbv:latest`
`make release-publish APP_NAME=app IMAGE_TAG=latest`
`make release-deploy APP_NAME=app ENVIRONMENT_NAME=dev IMAGE_TAG=latest`

After making changes to infrastructure, deploy them via:
`make infra-update-app-service APP_NAME=app ENVIRONMENT=dev`

## Security

### Authentication

TBD

### Inline `<script>` and `<style>` security

The system's Content-Security-Policy header prevents `<script>` and `<style>` tags from working without further
configuration. Use `<%= javascript_tag nonce: true %>` for inline javascript.

See the [CSP compliant script tag helpers](./doc/adr/0004-rails-csp-compliant-script-tag-helpers.md) ADR for
more information on setting these up successfully.

## Internationalization

### Managing locale files

We use the gem `i18n-tasks` to manage locale files. Here are a few common tasks:

Add missing keys across locales:
```
$ i18n-tasks missing # shows missing keys
$ i18n-tasks add-missing # adds missing keys across locale files
```

Key sorting:
```
$ i18n-tasks normalize
```

Removing unused keys:
```
$ i18n-tasks unused # shows unused keys
$ i18n-tasks remove-unused # removes unused keys across locale files
```

For more information on usage and helpful rake tasks to manage locale files, see [the documentation](https://github.com/glebm/i18n-tasks#usage).

## Testing

### Running tests

* Tests: `bundle exec rake spec`
* Ruby linter: `bundle exec rake standard`
* Accessibility scan: `./bin/pa11y-scan`
* Dynamic security scan: `./bin/owasp-scan`
* Ruby static security scan: `bundle exec rake brakeman`
* Ruby dependency checks: `bundle exec rake bundler:audit`
* JS dependency checks: `bundle exec rake yarn:audit`

Run everything: `bundle exec rake`

#### Pa11y Scan

When new pages are added to the application, ensure they are added to `./.pa11yci` so that they can be scanned.

### Automatic linting and terraform formatting
To enable automatic ruby linting and terraform formatting on every `git commit` follow the instructions at the top of `.githooks/pre-commit`

## CI/CD

GitHub actions are used to run all tests and scans as part of pull requests.

Security scans are also run on a scheduled basis. Weekly for static code scans, and daily for dependency scans.

### Deployment

TK

#### Staging

TK


#### Production

Deploys to production, including applying changes in terraform, happen
on every push to the `production` branch in GitHub.

The following secrets must be set within the `production` [environment secrets](https://docs.github.com/en/actions/reference/encrypted-secrets#creating-encrypted-secrets-for-an-environment)
to enable a deploy to work:

| Secret Name | Description |
| ----------- | ----------- |
| `CF_USERNAME` | cloud.gov SpaceDeployer username |
| `CF_PASSWORD` | cloud.gov SpaceDeployer password |
| `RAILS_MASTER_KEY` | `config/credentials/production.key` |
| `TERRAFORM_STATE_ACCESS_KEY` | Access key for terraform state bucket |
| `TERRAFORM_STATE_SECRET_ACCESS_KEY` | Secret key for terraform state bucket |

#### Non-secrets

Configuration that changes from staging to production, but is public, should be added to `config/deployment/staging.yml` and `config/deployment/production.yml`

## Monitoring with New Relic

The [New Relic Ruby agent](https://docs.newrelic.com/docs/apm/agents/ruby-agent/getting-started/introduction-new-relic-ruby) has been installed for monitoring this application.

The config lives at `config/newrelic.yml`, and points to a [FEDRAMP version of the New Relic service as its host](https://docs.newrelic.com/docs/security/security-privacy/compliance/fedramp-compliant-endpoints/). To access the metrics dashboard, you will need to be connected to VPN.

### Getting started

To get started sending metrics via New Relic APM:
1. Add your New Relic license key to the Rails credentials with key `new_relic_key`.
1. Optionally, update `app_name` entries in `config/newrelic.yml` with what is registered for your application in New Relic
1. Comment out the `agent_enabled: false` line in `config/newrelic.yml`
1. Add the [Javascript snippet provided by New Relic](https://docs.newrelic.com/docs/browser/browser-monitoring/installation/install-browser-monitoring-agent) into `application.html.erb`. It is recommended to vary this based on environment (i.e. include one snippet for staging and another for production).
## Analytics

Digital Analytics Program (DAP) code has been included for the Production environment, associated with GSA.

If Iv Cbv Payroll is for another agency, update the agency line in `app/views/layouts/application.html.erb`

## Documentation

### Architectural Decision Records

Architectural Decision Records (ADR) are stored in `doc/adr`
To create a new ADR, first install [ADR-tools](https://github.com/npryce/adr-tools) if you don't
already have it installed.
* `brew bundle` or `brew install adr-tools`

Then create the ADR:
*  `adr new Title Of Architectural Decision`

This will create a new, numbered ADR in the `doc/adr` directory.

Compliance diagrams are stored in `doc/compliance`. See the README there for more information on
generating diagram updates.

## Contributing

*This will continue to evolve as the project moves forward.*

* Pull down the most recent main before checking out a branch
* Write your code
* If a big architectural decision was made, add an ADR
* Submit a PR
  * If you added functionality, please add tests.
  * All tests must pass!
* Ping the other engineers for a review.
* At least one approving review is required for merge.
* Rebase against main before merge to ensure your code is up-to-date!
* Merge after review.
  * Squash commits into meaningful chunks of work and ensure that your commit messages convey meaning.

## Story Acceptance

TBD
