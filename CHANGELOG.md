# Changelog

All notable changes to Emmy App are documented here. Each entry is classified
**MAJOR**, **MINOR**, or **PATCH** per the rubric in
[docs/versioning.md](./docs/versioning.md).

MAJOR entries mean states should expect to update training materials or
integrations, and are accompanied by a notification.

## 0.10.0

### Emmy Income only user facing changes
- No changes, nothing to review!

### Emmy CE only user facing changes
- Add employment activities to ActivityJsonTransmitter [(#2130)](https://github.com/DSACMS/iv-cbv-payroll/pull/2130) - Tom Dooner [[FFS-4770]](https://jiraent.cms.gov/browse/FFS-4770)
- Add employment-focused entry page [(#2129)](https://github.com/DSACMS/iv-cbv-payroll/pull/2129) - Chris [[FFS-4859]](https://jiraent.cms.gov/browse/FFS-4859)
- Add education activities to ActivityJsonTransmitter [(#2131)](https://github.com/DSACMS/iv-cbv-payroll/pull/2131) - Daphne Gold [[FFS-4769]](https://jiraent.cms.gov/browse/FFS-4769)
- Update CE timeout page [(#2124)](https://github.com/DSACMS/iv-cbv-payroll/pull/2124) - Jake Wheeler [[FFS-4848]](https://jiraent.cms.gov/browse/FFS-4848)
- Add employment-focused Tokenized API endpoint [(#2112)](https://github.com/DSACMS/iv-cbv-payroll/pull/2112) - Chris [[FFS-4858]](https://jiraent.cms.gov/browse/FFS-4858)
- Update doc upload and review pages for unpaid/in-kind work in Emmy CE manual reporting flow [(#2125)](https://github.com/DSACMS/iv-cbv-payroll/pull/2125) - Daphne Gold [[FFS-4808]](https://jiraent.cms.gov/browse/FFS-4808)
- Update API Docs generation to occur on DSACMS/iv-cbv-payroll [(#2123)](https://github.com/DSACMS/iv-cbv-payroll/pull/2123) - Tom Dooner [[FFS-4389]](https://jiraent.cms.gov/browse/FFS-4389)
- Generate and publish OpenAPI developer documentation [(#2107)](https://github.com/DSACMS/iv-cbv-payroll/pull/2107) - Tom Dooner [[FFS-4389]](https://jiraent.cms.gov/browse/FFS-4389)

### Other/Maintenance (Not user facing)
- Bump vitest
- Update readme to keep testing flow up to date [(#2128)](https://github.com/DSACMS/iv-cbv-payroll/pull/2128) - iannorriswork
- No ticket: Update PR template to include new test deployment job link [(#2127)](https://github.com/DSACMS/iv-cbv-payroll/pull/2127) - Jake Wheeler
- Add Mixpanel events for employment month selection page [(#2126)](https://github.com/DSACMS/iv-cbv-payroll/pull/2126) - Daphne Gold [[FFS-4850]](https://jiraent.cms.gov/browse/FFS-4850)

## 0.9.0

### User facing changes to Emmy Income + Emmy CE
- Handle employer search timeouts gracefully [(#2101)](https://github.com/DSACMS/iv-cbv-payroll/pull/2101) - Jake Wheeler [[FFS-4849]](https://jiraent.cms.gov/browse/FFS-4849)
- No ticket: add asset to allow PDF to render [(#2100)](https://github.com/DSACMS/iv-cbv-payroll/pull/2100) - Tim Miller
- Update Argyle FLOW_ID to new account's flow [(#2079)](https://github.com/DSACMS/iv-cbv-payroll/pull/2079) - Tom Dooner [[FFS-4843]](https://jiraent.cms.gov/browse/FFS-4843)
- Set the default CBV invitation link expiration to 75 days for the Louisiana (LA) agency [(#2082)](https://github.com/DSACMS/iv-cbv-payroll/pull/2082) - Jake Wheeler [[FFS-4830]](https://jiraent.cms.gov/browse/FFS-4830)

### Emmy Income only user facing changes
- No changes, nothing to review!

### Emmy CE only user facing changes
- Update month selection and monthly details pages for unpaid/in-kind work in Emmy CE manual reporting flow [(#2111)](https://github.com/DSACMS/iv-cbv-payroll/pull/2111) - Daphne Gold [[FFS-4807]](https://jiraent.cms.gov/browse/FFS-4807)
- Add an environment variable to disable NSC in a given environment, forcing the Education flow to self-attestation only. [(#2047)](https://github.com/DSACMS/iv-cbv-payroll/pull/2047) - krista-skylight [[FFS-4713]](https://jiraent.cms.gov/browse/FFS-4713)
- Add headers to outbound document API [(#2102)](https://github.com/DSACMS/iv-cbv-payroll/pull/2102) - Daphne Gold [[FFS-4847]](https://jiraent.cms.gov/browse/FFS-4847)
- update v2 with latest [(#2105)](https://github.com/DSACMS/iv-cbv-payroll/pull/2105) - Chris [[FFS-4853]](https://jiraent.cms.gov/browse/FFS-4853)
- Remove prefilled activities [(#2070)](https://github.com/DSACMS/iv-cbv-payroll/pull/2070) - Chris [[FFS-4798]](https://jiraent.cms.gov/browse/FFS-4798)
- File type and max size settings for LA [(#2098)](https://github.com/DSACMS/iv-cbv-payroll/pull/2098) - Daphne Gold [[FFS-4846]](https://jiraent.cms.gov/browse/FFS-4846)
- Create v2 Invitations API separate endpoints [(#2078)](https://github.com/DSACMS/iv-cbv-payroll/pull/2078) - Chris [[FFS-4797]](https://jiraent.cms.gov/browse/FFS-4797)
- Create Aggregators::Sdk::NscFdshService for FDSH NSC test connection [(#2058)](https://github.com/DSACMS/iv-cbv-payroll/pull/2058) - Tom Dooner [[FFS-4711]](https://jiraent.cms.gov/browse/FFS-4711)
- Change content on employment information page for unpaid/in-kind work in Emmy CE manual reporting flow [(#2081)](https://github.com/DSACMS/iv-cbv-payroll/pull/2081) - Daphne Gold [[FFS-4805]](https://jiraent.cms.gov/browse/FFS-4805)

### Other/Maintenance (Not user facing)
- Bump vite, sass, @rails/actioncable, newrelic_rpm, parallel_tests, aws-sdk-s3, datadog, prettier, rubocop, autoprefixer, webpack, jsdom, vitest, datadog, prettier, faraday, go.opentelemetry.io/otel/sdk, aws-sdk-s3
- Create employment activity flow data model [(#2106)](https://github.com/DSACMS/iv-cbv-payroll/pull/2106) - Chris [[FFS-4855]](https://jiraent.cms.gov/browse/FFS-4855)
- Fix redaction for Argyle accounts linked previously [(#2097)](https://github.com/DSACMS/iv-cbv-payroll/pull/2097) - Tom Dooner [[FFS-4843]](https://jiraent.cms.gov/browse/FFS-4843)
- Fix Axe failures in E2E tests from Turbo navigation [(#2099)](https://github.com/DSACMS/iv-cbv-payroll/pull/2099) - Tim Miller
- Update markdown link checker to retry on 429 status [(#2108)](https://github.com/DSACMS/iv-cbv-payroll/pull/2108) - Tom Dooner
- Patch Dockerfile for OS-level CVEs flagged by Trivy/Anchore [(#2109)](https://github.com/DSACMS/iv-cbv-payroll/pull/2109) - github-actions[bot]
- No ticket: update AI attestation template [(#2103)](https://github.com/DSACMS/iv-cbv-payroll/pull/2103) - Tim Miller
- Add scripts to enable site alert and maintenance mode [(#2094)](https://github.com/DSACMS/iv-cbv-payroll/pull/2094) - Tom Dooner [[FFS-4841]](https://jiraent.cms.gov/browse/FFS-4841)
- Release 0.8.0 [(#2096)](https://github.com/DSACMS/iv-cbv-payroll/pull/2096) - Tom Dooner

## 0.8.0

### User facing changes to Emmy Income + Emmy CE
- Update Argyle FLOW_ID to new account's flow [(#2079)](https://github.com/DSACMS/iv-cbv-payroll/pull/2079) - Tom Dooner [[FFS-4843]](https://jiraent.cms.gov/browse/FFS-4843)
- Set the default CBV invitation link expiration to 75 days for the Louisiana (LA) agency [(#2082)](https://github.com/DSACMS/iv-cbv-payroll/pull/2082) - Jake Wheeler [[FFS-4830]](https://jiraent.cms.gov/browse/FFS-4830)

### Emmy Income only user facing changes
- No changes, nothing to review!

### Emmy CE only user facing changes
- Change content on employment information page for unpaid/in-kind work in Emmy CE manual reporting flow [(#2081)](https://github.com/DSACMS/iv-cbv-payroll/pull/2081) - Daphne Gold [[FFS-4805]](https://jiraent.cms.gov/browse/FFS-4805)

### Other/Maintenance (Not user facing)
- Bump aws-sdk-s3

## 0.7.0

### User facing changes to Emmy Income + Emmy CE
- Alternate text for images [(#2050)](https://github.com/DSACMS/iv-cbv-payroll/pull/2050) - Chris [[FFS-4819]](https://jiraent.cms.gov/browse/FFS-4819)
- Make alerts accessible [(#2055)](https://github.com/DSACMS/iv-cbv-payroll/pull/2055) - Chris [[FFS-4818]](https://jiraent.cms.gov/browse/FFS-4818)

### Emmy Income only user facing changes
- No changes, nothing to review!

### Emmy CE only user facing changes
- Update monthly details pages for paid work in Emmy CE manual reporting flow [(#2077)](https://github.com/DSACMS/iv-cbv-payroll/pull/2077) - Daphne Gold [[FFS-4822]](https://jiraent.cms.gov/browse/FFS-4822)
- Implement Education "Other" page (and its radio button) [(#2076)](https://github.com/DSACMS/iv-cbv-payroll/pull/2076) - krista-skylight [[FFS-4792]](https://jiraent.cms.gov/browse/FFS-4792)

### Other/Maintenance (Not user facing)
- Trigger AI workflows when draft PRs are ready for review [(#2080)](https://github.com/DSACMS/iv-cbv-payroll/pull/2080) - Daphne Gold
- No ticket: v0.6.0 version bump [(#2074)](https://github.com/DSACMS/iv-cbv-payroll/pull/2074) - Tim Miller

## 0.6.0

### Emmy Income only user facing changes
- No changes!

### Emmy CE only user facing changes
- Add month selection page to Emmy CE Employment flow [(#2071)](https://github.com/DSACMS/iv-cbv-payroll/pull/2071) - Daphne Gold [[FFS-4804]](https://jiraent.cms.gov/browse/FFS-4804)
- Implement Education type selection screen [(#2057)](https://github.com/DSACMS/iv-cbv-payroll/pull/2057) - krista-skylight [[FFS-4791]](https://jiraent.cms.gov/browse/FFS-4791)
- Create ActivityJsonTransmitter (with the 2 self-attested activity types) [(#2031)](https://github.com/DSACMS/iv-cbv-payroll/pull/2031) - Ben Calegari [[FFS-4768]](https://jiraent.cms.gov/browse/FFS-4768)
- FFS-4803: Update content on "Choose how you want to add your work" page on Emmy CE Employment flow, Update helper text on employment information page for paid work in Emmy CE manual reporting flow [(#2052)](https://github.com/DSACMS/iv-cbv-payroll/pull/2052) - Daphne Gold [[FFS-4802]](https://jiraent.cms.gov/browse/FFS-4802)

### Other/Maintenance (Not user facing)
- Create v2 invitations api [(#2033)](https://github.com/DSACMS/iv-cbv-payroll/pull/2033) - Chris [[FFS-4796]](https://jiraent.cms.gov/browse/FFS-4796)
- Bump aws-sdk-s3, vite, happy-dom, autoprefixer, postcss, sass, net-imap, selenium-webdriver, mission_control-jobs, css_parser
- fix: app/analytics/requirements.txt to reduce vulnerabilities [(#2072)](https://github.com/DSACMS/iv-cbv-payroll/pull/2072) - Tim Miller
- Remove bencalegari from reviewer lottery [(#2056)](https://github.com/DSACMS/iv-cbv-payroll/pull/2056) - krista-skylight
- Add environment selection to deploy script [(#2049)](https://github.com/DSACMS/iv-cbv-payroll/pull/2049) - Tom Dooner [[FFS-4794]](https://jiraent.cms.gov/browse/FFS-4794)

## 0.5.0

### Emmy Income only user facing changes
- No changes!

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
- No changes!

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
