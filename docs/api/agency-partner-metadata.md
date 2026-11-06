Metadata links a submitted report to the agency's records. Select the schema
for the API version, invitation type, and agency associated with your API key.
Some agency schemas overlap, so matching a schema alone does not identify the
agency.

For Louisiana, use the following metadata fields for each Emmy flow:

| Emmy flow | Tokenized Link API endpoint | Metadata fields |
| --- | --- | --- |
| Employment | `POST /api/v2/employment/invitations` | `individual_id`, `first_name`, `last_name` |
| CE | `POST /api/v2/community-engagement/invitations` | `individual_id`, `first_name`, `last_name`, `date_of_birth` |
| Income | `POST /api/v1/income/invitations` | `doc_id` |

For V1 income invitations, the response contains all accepted metadata fields
for the agency, with `null` for omitted values. Unrecognized fields are
ignored.

For V2 invitations, the response echoes the accepted metadata fields supplied
in the request. Unrecognized fields are ignored, and omitted optional fields
are not added to the response. Select the agency's community engagement or
employment schema to see the accepted and required fields, including
`individual_id`.

Both JSON report webhooks include the agency's V1 metadata field set when no individual_id was supplied. When an individual_id was supplied during V2 invitation creation, they include the agency's V2 metadata field set, including that exact ID. Unavailable values are sent as null; individual_id is omitted when it was not supplied.

Supply dates of birth as `MM/DD/YYYY`. Invitation responses echo date strings
as supplied. **Louisiana Emmy CE requests require `date_of_birth`** in
`agency_partner_metadata`, along with `individual_id`, `first_name`, and
`last_name`. This applies to `POST /api/v2/community-engagement/invitations`;
V2 employment invitations do not accept `date_of_birth`.
