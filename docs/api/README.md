# Emmy Platform API

Emmy helps agencies collect income and community engagement information from
applicants. Its Tokenized Link API creates personalized reporting links that
an agency can deliver through its own website, email, or SMS workflow.

<!-- These generated URLs are unavailable until the first reviewed deployment.
Remove the two link-check exceptions below after that deployment. -->
<!-- markdown-link-check-disable-next-line -->
The official [Emmy Platform API Documentation](https://DSACMS.github.io/iv-cbv-payroll/index.html)
contains authentication guidance, environment URLs, agency-specific schemas,
and tested request and response examples.

<!-- markdown-link-check-disable-next-line -->
The accompanying [OpenAPI JSON](https://DSACMS.github.io/iv-cbv-payroll/openapi.json) is generated
by the same build; do not maintain or commit a separate copy.

Contact [emmy@cms.hhs.gov](mailto:emmy@cms.hhs.gov) for onboarding and an API key
for each environment. Keep keys server-side and send requests over HTTPS.
The Dev environment is `https://verify-demo.navapbc.cloud`; the Demo environment
is `https://demo.reportmyincome.org`. Production access is arranged during onboarding.

The generated reference currently covers `POST /api/v1/invitations`.
Outbound report and document transmission interfaces will be added separately.
For those APIs, see the [CE activity report transmission guide](ce-activity-report.md)
and [PDF document transmission guide](pdf-transmission.md).
Existing versioned [income-report](schemas/income-report-2026-06-18.json) and
[community engagement report](schemas/ce-activity-report-2026-09-01.json) schemas
remain available for those integrations.

## Build and maintain the reference

After [setting up the application](../../CONTRIBUTING.md#setup), run from `app/`
with PostgreSQL available:

```bash
bundle install
npm ci
RAILS_ENV=test bundle exec rake api_docs:build
```

The build runs the rswag request specs, validates the OpenAPI document and all
published examples, then writes `index.html`, `openapi.json`, and local Scalar
assets to `app/tmp/api-docs/`. Open `index.html` directly in a browser; the site
works offline and does not submit API requests.

Edit [request specs](../../app/spec/requests/api/invitations_spec.rb),
[schemas](../../app/spec/openapi/invitation_schemas.rb),
[overview](overview.md), [invitation operation description](post-v1-invitations.md#description),
[agency metadata description](agency-partner-metadata.md),
[invitation response description](post-v1-invitations.md#response), and
[document settings](../../app/spec/swagger_helper.rb), not generated files.
The build reads these Markdown descriptions directly from `docs/api/`; Markdown
changes also trigger the publication workflow after merge.
Keep endpoint descriptions and responses together, using level-two headings
to identify the sections included in the generated reference.
Set `additionalProperties: true` on every OpenAPI object schema, including nested
objects, so integrations can tolerate additive schema changes.
Examples come from real test requests using synthetic data and fixed tokens;
authorization headers are never captured.

Pull request CI builds an `api-reference` artifact for review. After this change
is merged into `DSACMS/iv-cbv-payroll`, the
[publication workflow](../../.github/workflows/api-docs.yml) rebuilds on `main`
updates (or manual dispatch from `main`), commits the generated files to
`gh-pages` (creating the branch on its first run), and requests a Pages build.
Configure GitHub Pages to publish from `gh-pages`, `/`. Publication is restricted
to the canonical repository's `main` branch, never pull requests or forks.
Review the CI artifact before merging; do not publish local builds directly.
