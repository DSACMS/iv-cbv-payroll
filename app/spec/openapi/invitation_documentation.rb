module InvitationDocumentation
  SITE_URL = "https://CMS-Enterprise.github.io/emmy-app/index.html".freeze

  OVERVIEW = <<~MARKDOWN.freeze
    Integrate your agency's systems with the Emmy platform. This reference currently
    covers the Tokenized Link API for creating personalized reporting links.
    V2 invitations and outbound report payloads are separate interfaces and are not
    yet covered here. Examples use synthetic applicant data and nonfunctional tokens.

    [Download the official OpenAPI JSON](https://CMS-Enterprise.github.io/emmy-app/openapi.json).
    The JSON and this reference are generated together from executable API tests.

    ## API environments

    | Environment | Base URL | Purpose |
    | :-- | :-- | :-- |
    | Dev | https://verify-demo.navapbc.cloud | Develop and test integrations. |
    | Demo | https://demo.reportmyincome.org | Demonstrate and evaluate the platform. |

    Use HTTPS for every request and the API key issued for the selected environment.
    Your production hostname and credentials are provided during agency onboarding.

    ## API keys and authentication

    Contact [emmy@cms.hhs.gov](mailto:emmy@cms.hhs.gov) to request an agency API key
    for each environment. The Tokenized Link API uses a 32-character secret API key.
    Keep it on your server, never in browser code or public repositories.

    Each key identifies an agency and its configured metadata and invitation settings.
    Sending a `client_agency_id` cannot select another agency. Include these headers:

    ```http
    Authorization: Bearer API_KEY
    Content-Type: application/json
    ```

    A missing or invalid key returns `401 Unauthorized` with the plain-text body
    `HTTP Token: Access denied.` and a `WWW-Authenticate` header. If a key is
    compromised, contact emmy@cms.hhs.gov to have it replaced.
  MARKDOWN

  CREATE_INVITATION = <<~MARKDOWN.freeze
    Create a personalized income reporting link. Supply `language` (`en` or `es`)
    and an `agency_partner_metadata` object using your agency's schema.
    The API key determines which agency schema applies; it is not selected by the payload.

    The endpoint does not send email or SMS. Deliver the returned link or redirect
    the applicant to it. Each request creates a new invitation; there is no
    idempotency key or deduplication. Treat tokens as opaque.

    When enabled for the agency, a nonempty, valid `activities` array also creates
    an activity invitation. Each activity type must be enabled for the agency.
    An omitted or empty array produces only an income invitation. When prefilled
    activities are disabled, the array is ignored.

    **Validation:** `422` responses contain field paths and human-readable messages.
    Do not depend on exact message wording. Activity validation happens after the
    income invitation has been saved; retrying creates another income invitation.
    Missing metadata or malformed containers may raise a server error instead of
    a structured `422`. Always send metadata as an object and activities as an
    array of objects.

    **Origin tracking:** To track where an applicant received a link, append an
    `origin` query parameter with a value agreed during onboarding, such as `email`.
    Use `?` when the URL has no query string and `&` otherwise.
  MARKDOWN

  METADATA = <<~MARKDOWN.freeze
    Metadata links a submitted report to the agency's records. Select the schema
    for the agency associated with your API key. Sandbox and Louisiana have
    separate field sets; do not combine them. Some agency schemas overlap, so
    matching a schema alone does not identify the agency.

    Unrecognized fields and `individual_id` are ignored by this V1 endpoint.
    The response contains all accepted fields for the agency, with `null` for
    omitted values. Values are echoed as supplied, including date strings.
    Supply dates of birth as `MM/DD/YYYY`.
  MARKDOWN

  LINK_LIFETIME = <<~MARKDOWN.freeze
    Direct the applicant to `tokenized_url` to report income. Its `expiration_date`
    is the end of the day in `America/New_York` after the agency's configured
    validity period (14 days for the sandbox). Request a new invitation when a
    link expires. The optional `activity_tokenized_url` has no time-based
    expiration; `expiration_date` describes only the income link.
  MARKDOWN
end
