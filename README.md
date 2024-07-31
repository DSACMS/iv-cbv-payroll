Income Verification: Consent-Based Verification (Payroll)
========================

# About the Project

Consent-Based Verification (CBV) is an approach to allow benefit applicants to opt to verify their income via products that pull directly from payroll providers. This repository implements a product to demonstrate this technology for testing and validation purposes.

# Development and Software Delivery Lifecycle

If you're new to Rails, see the [Getting Started with Rails](https://guides.rubyonrails.org/getting_started.html)
guide for an introduction to the framework.

## Setup

* All of these steps need to be run within the `app` directory
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
  * `nodenv rehash`
* Start postgres & redis:
  * `brew services start postgresql@12`
  * `brew services start redis`
* Get development credentials from 1Password, search for "CBV Rails Secrets" and copy its ".env.development.local" section into a file called that in the "app" directory.
* Create database: `bin/rails db:create`
* Run migrations: `bin/rails db:migrate`
* Run the development server: `bin/dev`
* Visit the site: http://localhost:3000

## Local Development

Environment variables can be set in development using the [dotenv](https://github.com/bkeepers/dotenv) gem.

Any changes to variables in `.env` that should not be checked into git should be set in `.env.local`.

If you wish to override a config globally for the `test` Rails environment you can set it in `.env.test.local`.
However, any config that should be set on other machines should either go into `.env` or be explicitly set as part
of the test.

To run locally, use `bin/dev`

## Branching model
When beginning work on a feature, create a new branch based off of `main` and make the commits for that feature there.

We intend to use short-lived branches so as to minimize the cost of integrating each feature into the main branch.

## Story Acceptance

TBD

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

# Testing

## Running tests

* Tests: `bundle exec rake spec`
* Ruby linter: `bundle exec rake standard`
* Accessibility scan: `./bin/pa11y-scan`
* Dynamic security scan: `./bin/owasp-scan`
* Ruby static security scan: `bundle exec rake brakeman`
* Ruby dependency checks: `bundle exec rake bundler:audit`
* JS dependency checks: `bundle exec rake npm:audit`

Run everything: `bundle exec rake`

## Pa11y Scan

When new pages are added to the application, ensure they are added to `./.pa11yci` so that they can be scanned.

## Coding style and linters

To enable automatic ruby linting and terraform formatting on every `git commit` follow the instructions at the top of `.githooks/pre-commit`

## CI/CD

GitHub actions are used to run all tests and scans as part of pull requests.

Security scans are also run on a scheduled basis. Weekly for static code scans, and daily for dependency scans.

# Deployment

TK

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
