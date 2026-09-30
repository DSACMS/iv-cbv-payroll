Metadata links a submitted report to the agency's records. Select the schema
for the agency associated with your API key. Sandbox and Louisiana have
separate field sets; do not combine them. Some agency schemas overlap, so
matching a schema alone does not identify the agency.

Unrecognized fields and `individual_id` are ignored by this V1 endpoint.
The response contains all accepted fields for the agency, with `null` for
omitted values. Values are echoed as supplied, including date strings.
Supply dates of birth as `MM/DD/YYYY`.
