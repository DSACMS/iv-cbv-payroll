# Emmy Platform API

Emmy helps agencies collect income and community engagement information from
applicants. Its Tokenized Link API creates personalized reporting links that
an agency can deliver through its own website, email, or SMS workflow.

The official [Emmy Platform API Documentation](https://DSACMS.github.io/iv-cbv-payroll/index.html)
contains authentication guidance, environment URLs, agency-specific schemas,
and tested request and response examples.

The accompanying [OpenAPI JSON](https://DSACMS.github.io/iv-cbv-payroll/openapi.json) is generated
by the same build; do not maintain or commit a separate copy.

Contact [emmy@cms.hhs.gov](mailto:emmy@cms.hhs.gov) for onboarding and an API key
for each environment. Keep keys server-side and send requests over HTTPS.
The Dev environment is `https://verify-demo.navapbc.cloud`; the Demo environment
is `https://demo.reportmyincome.org`. Production access is arranged during onboarding.

The generated reference covers `POST /api/v1/invitations`,
`POST /api/v2/{invitation_type}/invitations`, the document delivery webhook, and the CE Activity Report webhook, including self-attested and validated employment and
self-attested, verified, and partially self-attested education. Find the webhook under **Receiving data from the Emmy Platform** in the left navigation,
with request and response examples and a signed cURL delivery sample.
CE reports are outbound payloads sent to an agency; their component schemas
also appear under Models. The Documents section includes the document delivery
contract, with retry behavior in a shared section; Income Reports (JSON) remains a placeholder.
For those APIs, see the [CE activity report transmission guide](receiving-data/ce-activity-json.md)
and [document transmission guide](receiving-data/pdf-transmission.md).
The generated OpenAPI document is the source for current schemas and tested
request and response examples.

## Reference sections

The Markdown files follow the generated reference's navigation:

| Reference section | Markdown source |
| :-- | :-- |
| Introduction and its subsections | [introduction.md](introduction.md) |
| V1 invitations | [invitations.md](invitations.md) |
| V2 invitations | [invitations-v2.md](invitations-v2.md) |
| Receiving data overview | [receiving-data/README.md](receiving-data/README.md#overview) |
| Report delivery flow | [receiving-data/report-delivery-flow.md](receiving-data/report-delivery-flow.md) |
| Retry logic | [receiving-data/retry-logic.md](receiving-data/retry-logic.md) |
| Webhook signatures | [receiving-data/webhook-signatures.md](receiving-data/webhook-signatures.md) |
| Receive a CE Activity Report (JSON) | [receiving-data/ce-activity-json.md](receiving-data/ce-activity-json.md) |
| Income Reports (JSON) | [receiving-data/income-reports.md](receiving-data/income-reports.md) |
| Receive a Document | [receiving-data/pdf-transmission.md](receiving-data/pdf-transmission.md) |

Level-two headings in `introduction.md` appear as subsections under Introduction.
The receiving-data group starts with an Overview sourced from the Overview
heading in `receiving-data/README.md`. Each report's own guide supplies its
specific introduction.
The report delivery flow embeds [api-flow.png](receiving-data/api-flow.png), which is included in the
generated site. Add future delivery-method documents under `receiving-data/`
and connect their contracts to the receiving-data tag.

## Build and maintain the reference

After [setting up the application](../../CONTRIBUTING.md#setup), run from `app/`
with PostgreSQL available:

```bash
bundle install
npm ci
RAILS_ENV=test bundle exec rake api_docs:build
```

The build runs the request, model, and CE transmission specs, validates the OpenAPI document and all
published examples, then writes `index.html`, `openapi.json`, `api-flow.png`, and
local Scalar assets to `app/tmp/api-docs/`. Open `index.html` directly in a browser; the site
works offline and does not submit API requests.

The build also exports education JSON samples to `app/tmp/ce-education-reports/`.

Edit [V1 request specs](../../app/spec/requests/api/invitations_spec.rb),
[V2 request specs](../../app/spec/requests/api/v2/invitations_spec.rb),
[invitation schemas](../../app/spec/openapi/invitation_schemas.rb),
[CE report models](../../app/spec/openapi/activity_report_schemas.rb),
[webhook contract](../../app/spec/openapi/activity_report_webhook.rb),
[document webhook contract](../../app/spec/openapi/document_webhook.rb),
[receiving data introduction](receiving-data/README.md),
[CE report description](receiving-data/ce-activity-json.md#model),
[document transmission guide](receiving-data/pdf-transmission.md),
[introduction](introduction.md), [invitation operation description](invitations.md#description),
[V2 invitation description](invitations-v2.md),
[agency metadata description](agency-partner-metadata.md),
[invitation response description](invitations.md#response), and
[document settings](../../app/spec/swagger_helper.rb), not generated files.
The build reads these Markdown descriptions directly from `docs/api/`; Markdown
changes also trigger the publication workflow after merge.
The document webhook reads sections of `receiving-data/pdf-transmission.md`
directly, so its endpoint, headers, request body, and response handling are
maintained in Markdown. Shared retry guidance lives in
[receiving-data/retry-logic.md](receiving-data/retry-logic.md).
Keep endpoint descriptions and responses together, using level-two headings
to identify the sections included in the generated reference.
V2 agency metadata fields and required fields are read from each agency's
`api.v2.community_engagement` and `api.v2.employment` configuration in
[client-agency-config.yml](../../app/config/client-agency-config.yml).
Update that configuration and rebuild the reference rather than maintaining a
separate V2 field list in the invitation schemas.
The reference uses OpenAPI 3.1. Use `additionalProperties: true` on objects so
integrations can tolerate additive schema changes. Month-keyed activity maps
also use `patternProperties` to validate arrays under `YYYY-MM` keys while
allowing future fields with other names. Nullable fields include `null` in their
`type` array.
Request examples come from real test requests using synthetic data and fixed
tokens. The CE model example comes from the transmission specs; model examples
and webhook request and response examples are validated during the build.
The webhook reuses the tested CE model example. Its description includes the
entire CE report guide. Shared signing guidance and the tested cURL sample live
on the separate Webhook signatures page in the receiving-data navigation group.
The response example is extracted from the CE guide's Response section. Add future delivery
methods under the same receiving-data tag. Authorization headers are never captured.

Pull request CI builds an `api-reference` artifact for review. After this change
is merged into `DSACMS/iv-cbv-payroll`, the
[publication workflow](../../.github/workflows/api-docs.yml) rebuilds on `main`
updates (or manual dispatch from `main`), commits the generated files to
`gh-pages` (creating the branch on its first run), and requests a Pages build.
Configure GitHub Pages to publish from `gh-pages`, `/`. Publication is restricted
to the canonical repository's `main` branch, never pull requests or forks.
Review the CI artifact before merging; do not publish local builds directly.
