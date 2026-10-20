Emmy signs outbound webhook requests with your agency's API key. Verify the
signature before processing the report. This signing scheme is shared by the
CE Activity Report, Income Report JSON, and PDF document deliveries.

## Signing headers

| Header | Description |
| :-- | :-- |
| `X-IVAAS-Timestamp` | Unix timestamp the request was signed at. |
| `X-IVAAS-Signature` | HMAC-SHA512 hexdigest of `"<timestamp>:<request body>"`, keyed with the agency's API key. |
| `X-IVAAS-Confirmation-Code` | The report's confirmation code. Sent with CE Activity Reports and document deliveries; omitted from Income Report JSON POSTs. |

Income Report JSON POSTs include `confirmation_code` in the JSON body but do not
send the `X-IVAAS-Confirmation-Code` header. They still include
`X-IVAAS-Timestamp` and `X-IVAAS-Signature`.

Any additional headers the agency requires (for example an API gateway key) can be configured per-agency and are sent verbatim.

Sign the exact bytes sent, including any trailing
newline; reformatting JSON after signing changes the signature.


## Verifying a signature

Compute an HMAC-SHA512 hex digest of the timestamp, a colon, and the exact raw
request body, using your agency's API key. Compare it with `X-IVAAS-Signature`
using a constant-time comparison. Use the `X-IVAAS-Timestamp` header as sent;
do not parse and reserialize the JSON before checking the signature.

## cURL example

Save the request payload shown in the OpenAPI reference as `ce-activity-report.json`.
Set `AGENCY_API_KEY` and `AGENCY_REPORT_URL` for your test receiver before running
this command. It simulates Emmy sending a report to your agency and requires
Bash, cURL, OpenSSL, and jq.

```bash
set -euo pipefail
: "${AGENCY_API_KEY:?Set AGENCY_API_KEY to your test agency API key}"
AGENCY_REPORT_URL="${AGENCY_REPORT_URL:-https://agency.example.org/api/v1/ce-activity-report}"
REPORT_FILE="${REPORT_FILE:-ce-activity-report.json}"

timestamp=$(date +%s)
confirmation_code=$(jq -er '.confirmation_code' "$REPORT_FILE")
signature=$(
  { printf '%s:' "$timestamp"; cat "$REPORT_FILE"; } |
    openssl dgst -sha512 -hmac "$AGENCY_API_KEY" | awk '{print $NF}'
)

curl --request POST "$AGENCY_REPORT_URL" \
  --header 'Content-Type: application/json' \
  --header "X-IVAAS-Timestamp: $timestamp" \
  --header "X-IVAAS-Signature: $signature" \
  --header "X-IVAAS-Confirmation-Code: $confirmation_code" \
  --data-binary "@$REPORT_FILE"
```

Add any agency-specific gateway headers configured during onboarding. The agency
API key is used for signing; this webhook does not use the invitation API's
`Authorization: Bearer` header.
