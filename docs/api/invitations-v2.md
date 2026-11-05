## Description

Create a personalized income reporting link and an activity reporting link
for the applicant described by `agency_partner_metadata`. The path segment
`invitation_type` selects which activity flow is created: `employment` or
`community-engagement`.

`verification_range` controls the reporting window for the activity
invitation (`last_complete_month` or `last_12_complete_months`).

## Response

Direct the applicant to `tokenized_url` to complete income verification, and
to `activity_tokenized_url` to complete the corresponding activity flow.
Treat both tokens as opaque.

`agency_partner_metadata` echoes the accepted fields supplied in the request,
using the same agency and invitation-type schema, including `individual_id`.
Unrecognized fields are ignored; omitted optional fields are not added to the
response. Date strings are echoed as supplied.
