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

## API environments

| Environment | Base URL | Purpose |
| :-- | :-- | :-- |
| Production | https://emmy.cms.gov | Run live integrations with your agency's highest environment. |
| UAT | https://uat.emmy.cms.gov | Perform integration testing with your agency's second-highest environment, for example UAT. |
| Production Sandbox | https://sandbox.emmy.cms.gov | Develop and test integrations with your agency's lowest environment, for example SIT. |

**Legacy environments support Emmy Income only.**

| Environment | Base URL | Purpose |
| :-- | :-- | :-- |
| Dev (Legacy) | https://verify-demo.navapbc.cloud | Develop and test Emmy Income integrations. |
| Demo (Legacy) | https://demo.reportmyincome.org | Demonstrate and evaluate Emmy Income. |

These URLs host the invitation API. Report webhooks use your agency's configured
receiver URL instead.

Use the API key issued for the selected environment. Credentials are provided
during agency onboarding.

## Networking

Use the following IP addresses when configuring your agency's firewall
allowlists. Incoming and outgoing are from Emmy's perspective:

- **Incoming IP addresses** are the destination addresses for requests from your
  agency to Emmy, such as invitation API requests.
- **Outgoing IP addresses** are the source addresses for requests from Emmy to
  your agency, such as report and document webhooks.

All traffic uses **HTTPS with TLS 1.2 or later over TCP port 443**.
Continue to use the environment's hostname for API requests; the IP addresses
below are for network configuration.

| Environment | Incoming IP addresses | Outgoing IP addresses |
| :-- | :-- | :-- |
| Production | `18.213.216.33`, `44.211.14.94`, `52.20.193.29` | `3.215.248.116`, `52.73.87.18`, `54.209.184.111` |
| UAT | `18.235.177.44`, `52.205.81.42`, `52.6.231.243` | `35.171.156.207`, `3.223.173.67`, `34.197.38.57` |
| Production Sandbox | `100.26.93.171`, `35.169.122.224`, `44.213.152.175` | `98.91.6.41`, `32.193.216.192`, `32.194.27.148` |

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
