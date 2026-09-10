# Changelog

All notable changes to Emmy App are documented here. Each entry is classified
**MAJOR**, **MINOR**, or **PATCH** per the rubric in
[docs/versioning.md](./docs/versioning.md).

MAJOR entries mean states should expect to update training materials or
integrations, and are accompanied by a notification.

## 0.5.0

### Emmy Income only user facing changes
- No changes, nothing to review!

### Emmy CE only user facing changes
- CE PDF Implementation [(#2035)](https://github.com/DSACMS/iv-cbv-payroll/pull/2035) - Daphne Gold [[FFS-4718]](https://jiraent.cms.gov/browse/FFS-4718)
- Remove help link [(#2043)](https://github.com/DSACMS/iv-cbv-payroll/pull/2043) - Chris [[FFS-4642]](https://jiraent.cms.gov/browse/FFS-4642)
- Hide language selector [(#2029)](https://github.com/DSACMS/iv-cbv-payroll/pull/2029) - Chris [[FFS-4642]](https://jiraent.cms.gov/browse/FFS-4642)

### Other/Maintenance (Not user facing)
- Bump rubocop, google.golang.org/grpc, vitest, sass, tornado, google.golang.org/grpc, postcss-selector-parser, postcss-cli, lookbook, webpack, rails_semantic_logger, bootsnap, mixpanel-ruby
- Stop logging full validation error messages (PII risk) in Employment Self-Attested Mixpanel events [(#2034)](https://github.com/DSACMS/iv-cbv-payroll/pull/2034) - krista-skylight [[FFS-4717]](https://jiraent.cms.gov/browse/FFS-4717)
- Remove chromedriver dependency [(#2030)](https://github.com/DSACMS/iv-cbv-payroll/pull/2030) - Chris [[FFS-4289]](https://jiraent.cms.gov/browse/FFS-4289)
- Security audit: remove api token to streamline what the behavior actually would be [(#2016)](https://github.com/DSACMS/iv-cbv-payroll/pull/2016) - iannorriswork
- No consent pdf showing [(#2013)](https://github.com/DSACMS/iv-cbv-payroll/pull/2013) - Chris [[FFS-4596]](https://jiraent.cms.gov/browse/FFS-4596)
- No matching employments error should not crash pdf [(#2015)](https://github.com/DSACMS/iv-cbv-payroll/pull/2015) - Chris [[FFS-4525]](https://jiraent.cms.gov/browse/FFS-4525)

## 0.4.0

### Emmy Income only user facing changes
- Redact LALDH `case_number` [(#1998)](https://github.com/DSACMS/iv-cbv-payroll/pull/1998) - Tom Dooner [[FFS-4665]](https://jiraent.cms.gov/browse/FFS-4665)

### Emmy CE only user facing changes
- Manual employment entry incorrectly requires both income AND hours [(#2010)](https://github.com/DSACMS/iv-cbv-payroll/pull/2010) - krista-skylight [[FFS-4709]](https://jiraent.cms.gov/browse/FFS-4709)
- Update credit hours conversion to 1:13 [(#2011)](https://github.com/DSACMS/iv-cbv-payroll/pull/2011) - Daphne Gold [[FFS-4706]](https://jiraent.cms.gov/browse/FFS-4706)
- Add "Choose how you want to add your work" page to Emmy CE Employment flow [(#1997)](https://github.com/DSACMS/iv-cbv-payroll/pull/1997) - Ben Calegari [[FFS-4705]](https://jiraent.cms.gov/browse/FFS-4705)
- CE timeout screen header and copy incorrectly reference "Report My Income" instead of Emmy [(#1996)](https://github.com/DSACMS/iv-cbv-payroll/pull/1996) - Daphne Gold [[FFS-4643]](https://jiraent.cms.gov/browse/FFS-4643)

### Other/Maintenance (Not user facing)
- Bump newrelic_rpm, postcss-import, sass, happy-dom, pdf-reader, vite, @uswds/uswds, rack-mini-profiler, solid_queue
- Investigate and fix undefined method `identity` for an instance of `CbvFlow` [(#2009)](https://github.com/DSACMS/iv-cbv-payroll/pull/2009) - krista-skylight [[FFS-3788]](https://jiraent.cms.gov/browse/FFS-3788)
- Instrument Mixpanel events for the Education Self-Attested flow in Emmy CE [(#1995)](https://github.com/DSACMS/iv-cbv-payroll/pull/1995) - Tim Miller

## 0.2.0

### Emmy Income only user facing changes
- No changes, nothing to review!

### Emmy CE only user facing changes
- Add two more URLs for accenture iframe [(#1961)](https://github.com/DSACMS/iv-cbv-payroll/pull/1961) - Tom Dooner
- Upload supporting docs directly to S3 client-side [(#1955)](https://github.com/DSACMS/iv-cbv-payroll/pull/1955) - Ben Calegari [[FFS-4542]](https://jiraent.cms.gov/browse/FFS-4542)

### Other/Maintenance (Not user facing)
- Bump @rails/actioncable, happy-dom, rubocop, bootsnap, newrelic_rpm, datadog, redis, webpack, postcss, vite, hadolint/hadolint-action, jsdom, webpack-cli, solid_queue, aws-sdk-s3
- Fix documentation link checks [(#1965)](https://github.com/DSACMS/iv-cbv-payroll/pull/1965) - Tom Dooner
- Fix health check version contract [(#1964)](https://github.com/DSACMS/iv-cbv-payroll/pull/1964) - Daphne Gold
- Bump npm (fast-uri, nanoid) and system packages (libheif1) for vuln scans [(#1960)](https://github.com/DSACMS/iv-cbv-payroll/pull/1960) - Tom Dooner
- Bump json gem 2.21.1 -> 2.21.2 [(#1959)](https://github.com/DSACMS/iv-cbv-payroll/pull/1959) - github-actions[bot]
- Local Replication Guide [(#1928)](https://github.com/DSACMS/iv-cbv-payroll/pull/1928) - Nočnica Mellifera
- Adopt semantic versioning at 0.1.0 [(#1941)](https://github.com/DSACMS/iv-cbv-payroll/pull/1941) - Nočnica Mellifera
- Disable rack-mini-profiler in Sandbox, UAT, Production [by 8/18] [(#1954)](https://github.com/DSACMS/iv-cbv-payroll/pull/1954) - Daphne Gold [[FFS-4623]](https://jiraent.cms.gov/browse/FFS-4623)

## 0.1.0

First versioned release. Establishes the version line for Emmy App; no
functional change to the application.

- **MINOR** — Adopt semantic versioning with interface changes promoted to
  MAJOR. Rubric documented in [docs/versioning.md](./docs/versioning.md).
- **MINOR** — `GET /health` now reports the semantic version as `version` and
  the deployed image tag as `ref`.

### Before this release

Releases were published from `main` and tagged `deploy/prod/<timestamp>`, with
notes generated by `app/bin/will-deploy`. Those tags remain in the repository as
deploy markers; see the GitHub releases page for history prior to 0.1.0.
