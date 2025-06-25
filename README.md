Income Verification: Consent-Based Verification (Payroll)
========================

# About the Project

Consent-Based Verification (CBV) is a prototype that allows benefit applicants to verify their income directly using payroll providers. It is currently being piloted for testing and validation purposes.

# Development and Software Delivery Lifecycle

If you're new to Rails, see the [Getting Started with Rails](https://guides.rubyonrails.org/getting_started.html)
guide for an introduction to the framework.

## Setup

Most developers on the team code using macOS, so we recommend that platform if possible. Some of these steps may not apply to other platforms.

1. Install Xcode Command Line Tools: ```xcode-select --install```
1. Install homebrew dependencies: `brew bundle`
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
   * [Ngrok](https://ngrok.com/downloads): brew install ngrok/ngrok/ngrok
     * Sign up for an account: https://dashboard.ngrok.com/signup
     * run `ngrok config add-authtoken {token goes here}`
   * [pre-commit](https://pre-commit.com/)
     * This configures your local git to run linters locally during a git commit. See [#coding-style-and-linters](#coding-style-and-linters) for a summary of which ones we use.
     * Run `pre-commit install` to opt-into running these linters. (They will run during CI regardless.)
1. Set up rbenv and nodenv:
   * `echo 'if which nodenv >/dev/null 2>/dev/null; then eval "$(nodenv init -)"; fi' >> ~/.zshrc`
   * `echo 'if which rbenv >/dev/null 2>/dev/null; then eval "$(rbenv init -)"; fi' >> ~/.zshrc`
   * Close & re-open your terminal

**The following commands must be run in the app directory**
1. Install Ruby: `rbenv install`
1. Install NodeJS `nodenv install`
1. Install Ruby dependencies: `bundle install`
   * If you get an error from debase, run this command: ```gem install debase -v0.2.5.beta2 -- --with-cflags="-Wno-incompatible-function-pointer-types"```
   * Also we should probably fix this (TODO)
1. Install JS dependencies
   * `nodenv rehash`
   * `npm install`
1. Start postgres:
   * `brew services start postgresql@12`
1. Get development credentials from 1Password: search for "CBV .env.local secrets" and copy its ".env.local" section into a file called that in the app directory.
1. Create database: `bin/rails db:create`
1. Run migrations: `bin/rails db:migrate`
1. Run the development server: `bin/dev`
1. Visit the site: http://localhost:3000

## Local Development

Environment variables can be set in development using the [dotenv](https://github.com/bkeepers/dotenv) gem.

Any changes to variables in `.env` that should not be checked into git should be set in `.env.local`.

For a list of **which environment variables can be modified for local development**, see the comments in `.env.local`.

If you wish to override a config globally for the `test` Rails environment you can set it in `.env.test.local`.
However, any config that should be set on other machines should either go into `.env` or be explicitly set as part
of the test.

To run locally, use `bin/dev`

To run database migrations on the test environment that is used by rpec tests, run `RAILS_ENV=test bin/rails db:schema:load`

## Branching model
When beginning work on a feature, create a new branch based off of `main` and make the commits for that feature there.

We intend to use short-lived branches so as to minimize the cost of integrating each feature into the main branch.

## Story Acceptance

We strive for all features to be acceptance tested prior to merge. The process is outline in the [Github PR Template](/.github/pull_request_template.md).

# Security

## Authentication

TBD

## Inline `<script>` and `<style>` security

The system's Content-Security-Policy header prevents `<script>` and `<style>` tags from working without further
configuration. Use `<%= javascript_tag nonce: true %>` for inline javascript.

# Internationalization

## Managing locale files

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

## "Client Agency-specific" translations

The CBV pilot project is architected to be multi-tenant across jurisdictions we
are actively piloting with. Each jurisdiction's agency is configured as a
"client agency" in app/config/client-agency-config.yml and has a short "id", e.g. "az_des", "la_ldh",
and "sandbox".

We often need to adjust copy specific to each client agency. The preferred way to do it
is by using the `client_agency_translation` helper, which wraps Rails's `t` view helper
and looks for the current client agency's "id" as a sub-key of the given prefix.

Usage:

```erb
<%= client_agency_translation(".learn_more_html") %>
```

And the corresponding locale file:


```yaml
learn_more_html:
  az_des: Learn more about <strong>Arizona Department of Economic Security</strong>
  la_ldh: Learn more about <strong>Louisiana Department of Health</strong>
  sandbox: Learn more about <strong>CBV Test Agency</strong>
  default: Learn more about <strong>Default Agency</strong>
```

Similar to Rails's `t` helper, the string will be marked HTML-safe if its key
prefix ends with `_html`.

## Importing Translations

We have a custom rake task and translation service for importing translations from CSV files to YAML format. This allows for easy management and updating of locale files.

The service handles nested keys and maintains the hierarchical structure of the YAML file by merging the new locale entries with the existing ones.


### How the Translation Service Works

1. The service reads the specified CSV file from the `tmp` directory.
2. It processes each row, skipping empty rows or those marked as not needing translation.
3. For each valid row, it checks if the English key exists in the current `en.yml` file.
4. If the key exists, it adds the translation to the target locale's YAML structure.
5. It logs various statistics and information about the import process.
6. Finally, it writes the updated translations to the appropriate locale YAML file (e.g., `es.yml` for Spanish) and generates a metadata file with import details.

This translation import system allows for efficient management of translations across multiple locales.

### How to Import New Locales
> ℹ️ **Note:**
> Ensure your CSV file contains at least two columns:
> - A 'key' column with the translation keys
> - A column for the target locale, matching the file's prefix (e.g., 'es' for Spanish)
> - Other columns in the CSV will be ignored by the import script

**1.** Place your CSV file in the `tmp` directory of your Rails application.
**2.** Name your CSV file using the following convention: `<locale>_import[_<timestamp>].csv` (e.g., `es_import.csv` or `es_import_20230515120000.csv` for Spanish).
   > The timestamp in the filename is optional. If multiple files exist for a locale, the script will use the file with the latest timestamp.

**3.** Run the rake task with the desired locale code:

   ```
   rake translations:import[<locale>]
   ```

   For example, to import Spanish translations:

   ```
   rake translations:import[es]
   ```

   or to import with **overwrite mode**:

   ```
   rake translations:import[es,true]
   ```

# Testing

## Running tests (in the `app` subdirectory)

* Tests: `bundle exec rspec`
* E2E tests: `RUN_E2E_TESTS=1 bundle exec rspec spec/e2e/`
* Accessibility scan: `./bin/pa11y-scan`
* Dynamic security scan: `./bin/owasp-scan`
* Ruby style linter: `bundle exec rubocop`
* Ruby static security scan: `bundle exec rake brakeman`
* Ruby dependency checks: `bundle exec rake bundler:audit`
* JS dependency checks: `bundle exec rake npm:audit`

## Manual Testing
If you're new to CBV, here's a summary of how to get started navigating the app.
1. First, contact someone on the team to get you set up to log in.
1. Follow the instructions in the Setup section to run locally, then go to `localhost:3000/sandbox/sso`
1. The beginning of the workflow is to act as a caseworker to create an invitation. Start by signing in with your Nava credentials.
1. Create an invitation for an applicant to start using the app (use any email, and don't worry -- it won't really send!)
1. In your terminal session, navigate to the /app directory and run `rails c` to enter the irb prompt.
1. At the irb prompt, run `CbvFlowInvitation.last.to_url`.
1. Click the resulting link. Now you're ready to start acting as an applicant!
1. Search for your employer. When you select one, the local page will show you some fake credentials at the very bottom of the screen. Use these to sign in.
1. Finally, you should be able to complete the applicant flow, including looking at the PDF.
1. To complete the caseworker flow, add `?is_caseworker=true` to the /cbv/summary.pdf path to see the PDF that gets sent (it's different from the one we send the applicant!)
1. Note: You can switch to a different pilot partner (state) by going to the irb prompt and running `CbvFlow.last.update(client_agency_id: 'az_des')`. Right now you can only pass it `az_des`, `la_ldh`, or `sandbox`.

## Pa11y Scan

When new pages are added to the application, ensure they are added to `./.pa11yci` so that they can be scanned.

## Coding style and linters

To enable automatic ruby linting and terraform formatting on every `git commit`, run the command `pre-commit install`.

This will run linters as configured by `.pre-commit-config.yml` before every commit. (For performance, it only runs linters on files that are being changed in the commit.)

We use the following linters:

* **Ruby**: Rubocop, ErbLint
* **JavaScript**: Prettier
* **Markdown**: MarkdownLint
* **GH Actions**: ActionLint
* **Bash**: ShellCheck
* **Terraform**: `terraform fmt`

## CI/CD

GitHub Actions are used to run all tests and scans as part of pull requests.

## Vulnerability Scanning

We also run vulnerability scanners on every pull request. See [Vulnerability Management](/docs/infra/vulnerability-management.md) documentation for more details.

## Running a production image locally

To debug locally an image built for deployment, see [the Running Built Images Locally runbook](/docs/app/runbooks/running-built-images-locally.md).


# Deployment

## Demo

This repo's `main` branch automatically deploys to our demo environment via [a GitHub action](/.github/workflows/cd-app.yml).

## Production

To deploy to production, go to the repo's "Actions" tab on Github, [click "Deploy App"](https://github.com/DSACMS/iv-cbv-payroll/actions/workflows/cd-app.yml), and "Run Workflow".

# Credentials and other Secrets

TK

## Non-secrets

TK

# Monitoring with New Relic

The [New Relic Ruby agent](https://docs.newrelic.com/docs/apm/agents/ruby-agent/getting-started/introduction-new-relic-ruby) has been installed for monitoring this application.

The config lives at `config/newrelic.yml`, and points to a [FEDRAMP version of the New Relic service as its host](https://docs.newrelic.com/docs/security/security-privacy/compliance/fedramp-compliant-endpoints/). To access the metrics dashboard, you will need to be connected to VPN.

## Getting started

To get started sending metrics via New Relic APM:
1. Add your New Relic license key to the Rails credentials with key `new_relic_key`.
1. Optionally, update `app_name` entries in `config/newrelic.yml` with what is registered for your application in New Relic
1. Comment out the `agent_enabled: false` line in `config/newrelic.yml`
1. Add the [Javascript snippet provided by New Relic](https://docs.newrelic.com/docs/browser/browser-monitoring/installation/install-browser-monitoring-agent) into `application.html.erb`. It is recommended to vary this based on environment (i.e. include one snippet for staging and another for production).

## Analytics

Digital Analytics Program (DAP) code has been included for the Production environment, associated with GSA.

If Iv Cbv Payroll is for another agency, update the agency line in `app/views/layouts/application.html.erb`

# Documentation

## Repository Structure
See [CODEOWNERS.md](./CODEOWNERS.md) for some information on repo structure.

## Documentation Index

Documentation is currently stored in CMS Confluence:
https://confluenceent.cms.gov/display/SFIV/Consent-based+Verification+%28CBV%29+for+Payroll

## Architectural Decision Records

Our ADRs are stored in CMS Confluence: https://confluenceent.cms.gov/pages/viewpage.action?pageId=693666588

# Contributing
See [CONTRIBUTING.md](./CONTRIBUTING.md).

## Community

The CBV team is taking a community-first and open source approach to the product development of this tool. We believe government software should be made in the open and be built and licensed such that anyone can download the code, run it themselves without paying money to third parties or using proprietary software, and use it as they will.

We know that we can learn from a wide variety of communities, including those who will use or will be impacted by the tool, who are experts in technology, or who have experience with similar technologies deployed in other spaces. We are dedicated to creating forums for continuous conversation and feedback to help shape the design and development of the tool.

We also recognize capacity building as a key part of involving a diverse open source community. We are doing our best to use accessible language, provide technical and process documents, and offer support to community members with a wide variety of backgrounds and skillsets.

## Community Guidelines
See [COMMUNITY_GUIDELINES.md](./COMMUNITY_GUIDELINES.md).

## Governance

See [GOVERNANCE.md](./GOVERNANCE.md)

## Feedback

If you have ideas for how we can improve or add to our capacity building efforts and methods for welcoming people into our community, please let us know by sending an email to: ffs at nava pbc dot com. If you would like to comment on the tool itself, please let us know by filing an **issue on our GitHub repository.**

## Policies

### Open Source Policy

We adhere to the [CMS Open Source
Policy](https://github.com/CMSGov/cms-open-source-policy). If you have any
questions, just [shoot us an email](mailto:opensource@cms.hhs.gov).

### Security and Responsible Disclosure Policy

<!-- markdown-link-check-disable -->
*Submit a vulnerability:* Unfortunately, we cannot accept secure submissions via
email or via GitHub Issues. Please use our website to submit vulnerabilities at
[https://hhs.responsibledisclosure.com](https://hhs.responsibledisclosure.com/).
HHS maintains an acknowledgements page to recognize your efforts on behalf of
the American public, but you are also welcome to submit anonymously.
<!-- markdown-link-check-enable -->

For more information about our Security, Vulnerability, and Responsible Disclosure Policies, see [SECURITY.md](SECURITY.md).

### Public domain

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/) as indicated in [LICENSE](LICENSE).

All contributions to this project will be released under the CC0 dedication. By submitting a pull request or issue, you are agreeing to comply with this waiver of copyright interest.

# Core Team

See [CODEOWNERS.md](./CODEOWNERS.md)
