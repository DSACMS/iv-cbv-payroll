Contact the Emmy Team to request documentation about the Income Report API.

Income Report JSON POSTs include `confirmation_code` in the JSON body, but do
not send the `X-IVAAS-Confirmation-Code` header. The `X-IVAAS-Timestamp` and
`X-IVAAS-Signature` headers are included for signature verification.
