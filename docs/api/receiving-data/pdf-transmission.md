## Overview

This API lets your agency receive documents from the Emmy platform, including
income report PDFs and supporting activity documents.
It is an alternative to other file delivery methods, such as SFTP, S3, or shared
email. Your agency hosts the receiving endpoint and ensures that documents are
added to the correct case in its eligibility management system.

For agencies that also receive income data through the Income Report JSON API,
Emmy sends the PDF after the JSON delivery succeeds.

## Receive a Document

The endpoint receives one document per HTTP POST request. `/api/v1/documents` is a
suggested path; your agency can choose another path that includes a version
number. Arrange the receiver URL during onboarding and accept requests only
over HTTPS.

Use the shared [Webhook signatures](webhook-signatures.md)
guidance for signing headers, signature verification, and any additional
agency-specific headers. Verify the signature against the exact document bytes
received in the request body.

## Request body

The document is sent as raw bytes in the request body, without a JSON or multipart
wrapper. Any MIME type is supported; `Content-Type` identifies the document
format, such as `application/pdf`, `image/jpeg`, or `application/octet-stream`.

## Content-Type

MIME type of the document. Any MIME type is supported; income report PDFs use
`application/pdf`.

## Content-Length

Size of the document in bytes.

## Content-Disposition

Sent with supporting activity documents as `attachment; filename="<filename>"`
to identify the transmitted file's name. Not sent with income report PDFs.

## X-IVAAS-Document-Id

Sent with supporting activity documents to identify the document, matching its
`document_id` in the CE Activity Report. For example, `DOC-123`. Not sent with
income report PDFs.

## Response and error handling

Return `200 OK` when the document has been successfully received by your agency's
system. Emmy uses the HTTP status to determine delivery success and does not
validate the response body. The transmitter accepts any `2xx` success status;
other statuses cause delivery to fail and trigger a retry. See [Retry logic](retry-logic.md).

| HTTP status | Meaning | Emmy action |
| :-- | :-- | :-- |
| `200 OK` | The document was successfully received. | Mark delivery successful. |
| `401 Unauthorized` | Signature verification failed. | Retry delivery. |
| `500 Internal Server Error` | The receiving system could not process the request. | Retry delivery. |

Use appropriate error statuses, such as `400 Bad Request`, `404 Not Found`,
`408 Request Timeout`, `413 Content Too Large`, `429 Too Many Requests`, or
`502 Bad Gateway`, to help diagnose failed deliveries.
