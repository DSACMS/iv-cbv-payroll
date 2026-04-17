# How to Contribute

Eligibility Made Easy (Emmy) is being developed in the open by CMS and its contractors. We use internal tools to track our work (bugs and feature enhancements).

## Contribution Guidelines
While every raised pull request will be reviewed by the Emmy team, in general we don’t accept PRs that
* Don’t directly address an existing issue
* Touch more than 10 files at a time
* contain more than 10 commits
* Change core system files such as `Gemfile`, `.ruby-version` and `.nvmrc`
* Are untested / don’t pass our test suite / don’t pass our linters / don’t follow established style
* Are entirely AI generated

## Run Emmy for yourself

If you're new to Rails, see the [Getting Started with Rails](https://guides.rubyonrails.org/getting_started.html)
guide for an introduction to the framework.

### Setup

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

**The following commands must be run in the `/app` directory**
1. Install Ruby: `rbenv install`
1. Install NodeJS `nodenv install`
1. Install Ruby dependencies: `bundle install`
1. Install JS dependencies
   * `nodenv rehash`
   * `npm install`
1. Start postgres:
   * `brew services start postgresql@12`
1. Set up the environment variables you'll need.
   * `cp .env.local.example .env.local`
   * Follow directions in the .env.local file to set up your accounts and API keys for all necessary services.
   * Ask another engineer for the shared credentials (they're in Nava's 1Password under "CBV .env.local Rails Secrets")
1. Create database: `bin/rails db:create`
1. Run migrations: `bin/rails db:migrate`
1. Run the development server: `bin/dev`
1. Visit the site: http://localhost:3000

### For analytics development
#### First-time setup
1. Navigate to the `analytics` directory: `cd app/analytics`
1. Create the virtual environment: `python3 -m venv venv`
1. Activate the environment: `source venv/bin/activate`
1. Install dependencies: `pip install -r requirements.txt`
1. Add the following to your .env.local; you can find the credentials in the FFS Engineering 1Password under Mixpanel Production Service Account.
```
# Jupyter / Mixpanel analytics
MIXPANEL_PROJECT_ID=3511732
MIXPANEL_SERVICE_ACCOUNT_USERNAME=
MIXPANEL_SERVICE_ACCOUNT_SECRET=
```

#### To start writing new analytics or running analyses
6. Run `jupyter lab --NotebookApp.iopub_data_rate_limit=1.0e10` and open the analytics.ipynb file.
6. Modify the date parameters to define the range of the data you'd like to download. These can be found in the first block of executable code marked with the comment "date range". They're parameters we feed to the Mixpanel API.
6. Execute the first section with shift + enter. It will take a while to download all the events! Once you've run this once, you can proceed to run the other cells or write your own.

#### Analytics development tips
* Jupyter Notebooks are Python files that allow you to re-run cells of code easily. This first cell of code I wrote to pull a new dataset from our Mixpanel analytics platform. When developing analyses to run on that data set, we should start writing new cells below it. That way, when you want to get started, you can run the first cell just once to pull the data, and then you could run and re-run later cells as many times as you want to analyze that data.
* Before committing changes to the ipynb file, it's a good idea to go to the Kernel menu and select "Restart Kernel and Clear Outputs of All Cells...". This deletes the results from running the cells as well as various pieces of metadata, which will allow us to commit just the code changes added in a cell.


### Local Development

Environment variables can be set in development using the [dotenv](https://github.com/bkeepers/dotenv) gem.

Any changes to variables in `.env` that should not be checked into git should be set in `.env.local`.

For a list of **which environment variables can be modified for local development**, see the comments in `.env.local`.

If you wish to override a config globally for the `test` Rails environment you can set it in `.env.test.local`.
However, any config that should be set on other machines should either go into `.env` or be explicitly set as part
of the test.

To run locally, use `bin/dev`

To run database migrations on the test environment that is used by rpec tests, run `RAILS_ENV=test bin/rails db:schema:load`

#### JSON API Testing

To acceptance test the JSON API, you can run the independent **reference server implementation**.

1. **Create an API key for the agency you want to test:**
   ```bash
   cd app
   bin/rails 'users:create_api_token[agency_id]'
   ```

2. **Run the standalone test receiver:**
   ```bash
   JSON_API_KEY=$(bin/rails runner "puts User.api_key_for_agency('agency_id')") ruby lib/json_api_receiver.rb
   ```

3. **Configure Emmy App to POST to the reference server.** Add this to your `.env.local`:
   ```bash
   # For testing LA SFTP against sinatra reference implementation
   LA_LDH_TRANSMISSION_METHOD=json_and_pdf
   LA_LDH_INCOME_REPORT_URL=http://localhost:4567
   LA_LDH_PDF_API_URL=http://localhost:4567/pdf
   LA_LDH_INCOME_REPORT_APIKEY=foo
   LA_LDH_INCLUDE_REPORT_PDF=false
   LA_LDH_INCOME_REPORT_ACCOUNTCODE=foobar
   ```

This starts a standalone test server on port 4567 that logs incoming JSON data and verifies HMAC signatures. The receiver is completely independent and can be used as a reference implementation for agencies building their own JSON API endpoints.

### Branching model
When beginning work on a feature, create a new branch based off of `main` and make the commits for that feature there.

We intend to use short-lived branches so as to minimize the cost of integrating each feature into the main branch.

### Branch Workflow


We follow the [GitHub Flow Workflow](https://guides.github.com/introduction/flow/)

1.  Fork the project
2.  Check out the `main` branch
3.  Create a feature branch
4.  Write code and tests for your change
5.  From your branch, make a pull request against main
6.  Work with [repo maintainers](.github/CODEOWNERS.md) to get your change reviewed
7.  Wait for your change to be pulled into main
8.  Delete your feature branch

### Story Acceptance

We strive for all features to be acceptance tested prior to merge. The process is outline in the [Github PR Template](/.github/pull_request_template.md).

### Writing Pull Requests



Comments should be formatted to a width no greater than 80 columns.

Files should be exempt of trailing spaces.

We adhere to a specific format for commit messages. Please write your commit
messages along these guidelines. Please keep the line width no greater than 80
columns (You can use `fmt -n -p -w 80` to accomplish this).

    Some examples of good, understandable PR titles:

        FFS-1111: Fix missing translation on /entry page
        FFS-2222: Implement invitation reminder emails

    (The title of the pull request will be used in the eventual deploy log - so it's helpful to format the title to be understandable by other disciplines if possible.)

    ## Ticket

    either a JIRA ticket (internal to CMS) or GitHub issue

    ## Changes
    <!-- What was added, updated, or removed in this PR. -->


    ## Context for reviewers
    <!-- Anything you'd like other engineers on the team to know. -->


    ## Acceptance testing
    <!-- Check one: -->

    - [x] No acceptance testing needed
    * This change will not affect the user experience (bugfix, dependency updates, etc.)
    - [ ] Acceptance testing prior to merge
    * This change can be verified visually via screenshots attached below or by sending a link to a local development environment to the acceptance tester
    * Acceptance testing should be done by **design** for visual changes, **product** for behavior/logic changes, **or both** for changes that impact both.
    - [ ] Acceptance testing after merge
    * This change is hard to test locally, so we'll test it in the demo environment (deployed automatically after merge.)
    * Make sure to notify the team once this PR is merged so we don't inadvertently deploy the unaccepted change to production. (e.g. `:alert: Deploy block! @ffs-eng I just merged PR [#123] and will be doing acceptance testing in demo - please don't deploy until I'm finished!`)

    ## Infrastructure Changes
    <!-- If this PR includes Terraform changes, please provide relevant info. -->

    - [ ] Plan reviewed
    - [ ] Applied in dev before merge
    - [ ] Applied in demo after merge
    - [ ] Applied in prod after merge (note any exceptions or special coordination below)

    **Risk / Downtime:**
    <!-- Note exceptions, potential downtime, or required coordination -->

Some important notes regarding the summary line:

* Describe what was done; not the result
* Use the active voice
* Use the present tense
* Capitalize properly
* Do not end in a period — this is a title/subject
* Prefix the subject with its scope

    see our .github/PULL_REQUEST_TEMPLATE.md for more examples.
-->

## Reviewing Pull Requests

<!--- TODO: Make a brief statement about how pull-requests are reviewed, and who is doing the reviewing. Linking to MAINTAINERS.md can help.

Code Review Example

The repository on GitHub is kept in sync with an internal repository at
github.cms.gov. For the most part this process should be transparent to the
project users, but it does have some implications for how pull requests are
merged into the codebase.

When you submit a pull request on GitHub, it will be reviewed by the project
community (both inside and outside of github.cms.gov), and once the changes are
approved, your commits will be brought into github.cms.gov's internal system for
additional testing. Once the changes are merged internally, they will be pushed
back to GitHub with the next sync.

This process means that the pull request will not be merged in the usual way.
Instead a member of the project team will post a message in the pull request
thread when your changes have made their way back to GitHub, and the pull
request will be closed.

The changes in the pull request will be collapsed into a single commit, but the
authorship metadata will be preserved.

-->

<!--
## Shipping Releases

<!-- TODO: What cadence does your project ship new releases? (e.g. one-time, ad-hoc, periodically, upon merge of new patches) Who does so? 
-->

## Documentation

Place new documentation in the [/docs](docs/) repository 


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

## Public domain

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0 dedication. By submitting a pull request or issue, you are agreeing to comply with this waiver of copyright interest.
