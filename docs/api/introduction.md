# Introduction

Integrate your agency's systems with the Emmy platform. This reference currently
covers the Tokenized Link API (v1 and v2) for creating personalized reporting links and the
CE Activity Report webhook for outbound community engagement reports. Find the
webhook under **Receiving data from the Emmy Platform**, including its JSON
request example, signing headers, expected response, and signed cURL sample.
Its component models include self-attested employment, validated payroll, and education.
Your agency hosts this receiver.
Examples use synthetic applicant data and nonfunctional tokens.

Object schemas allow additional properties for forward compatibility. Integrations
should tolerate unknown response fields so new fields can be added without breaking
existing clients. Required fields and documented field types still apply.

<!-- Remove this link-check exception after the first reviewed deployment. -->
<!-- markdown-link-check-disable-next-line -->
[Download the official OpenAPI JSON](https://DSACMS.github.io/iv-cbv-payroll/openapi.json).
The JSON and this reference are generated together from executable API tests.

## Report delivery flow

Emmy sends a completed report to your agency's receiver, which verifies the
request signature, saves the report, and returns an HTTP response.

![Report delivery between Emmy and the agency system](api-flow.png)

The diagram shows the income report flow. The CE Activity Report uses your
agency's configured CE receiver URL, illustrated in this reference as
`/api/v1/ce-activity-report`.

## API environments

| Environment | Base URL | Purpose |
| :-- | :-- | :-- |
| Dev | https://verify-demo.navapbc.cloud | Develop and test integrations. |
| Demo | https://demo.reportmyincome.org | Demonstrate and evaluate the platform. |

These URLs host the invitation API. Report webhooks use your agency's configured
receiver URL instead.

Use HTTPS for every request and the API key issued for the selected environment.
Your production hostname and credentials are provided during agency onboarding.

## API keys and authentication

Contact [emmy@cms.hhs.gov](mailto:emmy@cms.hhs.gov) to request an agency API key
for each environment. The Tokenized Link API uses a 32-character secret API key.
Keep it on your server, never in browser code or public repositories.

For invitation requests, each key identifies an agency and its configured metadata and invitation settings.
Sending a `client_agency_id` cannot select another agency. Include these headers:

```http
Authorization: Bearer API_KEY
Content-Type: application/json
```

A missing or invalid key returns `401 Unauthorized` with the plain-text body
`HTTP Token: Access denied.` and a `WWW-Authenticate` header. If a key is
compromised, contact emmy@cms.hhs.gov to have it replaced.

Outbound report webhooks use HMAC signing headers instead of Bearer
authentication. See **Receiving data from the Emmy Platform** for verification
details and an example delivery to your agency.
