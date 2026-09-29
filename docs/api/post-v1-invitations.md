## Description

Create a personalized income reporting link. Supply `language` (`en` or `es`)
and an `agency_partner_metadata` object using your agency's schema.
The API key determines which agency schema applies; it is not selected by the payload.

The endpoint does not send email or SMS. Deliver the returned link or redirect
the applicant to it. Each request creates a new invitation; there is no
idempotency key or deduplication. Treat tokens as opaque.

This V1 endpoint creates only income invitations. The legacy `activities`
parameter is ignored; it does not create a community engagement invitation.

**Validation:** `422` responses contain field paths and human-readable messages.
Do not depend on exact message wording. Missing metadata or malformed metadata
containers may raise a server error instead of a structured `422`. Always send
`agency_partner_metadata` as an object.

**Origin tracking:** To track where an applicant received a link, append an
`origin` query parameter with a value agreed during onboarding, such as `email`.
Use `?` when the URL has no query string and `&` otherwise.

## Response

Direct the applicant to `tokenized_url` to report income. Its `expiration_date`
is the end of the day in `America/New_York` after the agency's configured
validity period (14 days for the sandbox). Request a new invitation when a
link expires.
