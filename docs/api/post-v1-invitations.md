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
