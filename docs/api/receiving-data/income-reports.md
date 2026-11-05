Contact the Emmy Team to request documentation about the Income Report API.

Income Report JSON POSTs include the agency's V1 `agency_partner_metadata`
fields. When `individual_id` was supplied during V2 invitation creation, the
webhook also includes that exact value; otherwise it omits the field. See the
[metadata guide](../agency-partner-metadata.md) for details.

Income Report JSON POSTs include `confirmation_code` in the JSON body, but do
not send the `X-IVAAS-Confirmation-Code` header. The `X-IVAAS-Timestamp` and
`X-IVAAS-Signature` headers are included for signature verification.
