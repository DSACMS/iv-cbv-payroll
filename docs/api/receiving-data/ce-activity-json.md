## Overview

Emmy sends completed reports to your agency's systems so they can be added to
the applicant's case. Your agency hosts the receiving endpoint and arranges its
URL and any additional headers during onboarding.

The CE Activity Report webhook below delivers JSON, including income and payroll
data. Its request body describes what your agency receives; its response describes
what your endpoint should return to Emmy. The example agency hostname is a
placeholder. Use your own receiver URL when testing delivery.

## Model

This document describes the **Community Engagement (CE) Activity Report Transmission API Specification**, a method by which CE activity data can be sent from the Eligibility made easy (Emmy) platform to an agency's systems.

The agency must build an API endpoint that meets this specification and integrates with agency systems to process the activity report into the case file for the correct client.

This revision covers `community_service`, `work_program`, `employment`, and `education`. Employment includes self-attested work and payroll data from linked Argyle or Pinwheel accounts. Education includes self-attested credits, verified NSC enrollment, and partially self-attested education.

## Transmission

Emmy sends a completed CE Activity Report as an HTTP `POST` to an endpoint
hosted by your agency. This is an outbound webhook, not an endpoint on Emmy's
Dev or Demo servers.

### POST /api/v1/ce-activity-report

This API endpoint is built by the agency and receives one CE activity report record. The endpoint URL can be whatever the agency desires, however, it must include a version number to allow for easy upgrades in the future.

The complete `CeActivityReport` model is published in the generated
OpenAPI reference, along with component models for the report,
review period, documents, activity types, and payroll details. Find the webhook
under **Receiving data from the Emmy Platform**. The request example
comes from the tested serializer and includes community service, work programs,
linked payroll, self-employment, unpaid work, and all three education variants.

### Request signatures

See [Webhook signatures](webhook-signatures.md) for signing headers,
verification guidance, and a signed cURL example for testing your receiver.

## Response

The agency should respond with `200` and a payload containing:

```json
{
  "status": "received",
  "confirmation_code": "SANDBOX123",
  "received_at": "2026-08-11T14:00:05Z",
  "schema_version_received": "1.0.0",
  "unrecognized_fields_detected": false
}
```

Emmy currently checks the HTTP status and does not validate this response body.

## Request body

The request body uses the `CeActivityReport` OpenAPI model. Expand its properties
and linked models in the reference for field descriptions, required and nullable
fields, monthly reporting rules, and the employment and education variants.
The generated request example shows a complete report with all activity types.

# **Design Principles**

| Design | Description |
| :-- | :-- |
| Tolerant Reader | Systems should accept payloads that contain unknown or extra fields without rejecting them. Only a minimal set of fields are truly required. |
| Additive-only schema evolution | New fields can be added to the spec at any time without breaking existing integrations. Fields are only removed in major version releases. |
| Soft required fields | Fields that should be present but may not always be available from upstream providers are not marked as required, and denote `null` as an acceptable value. |
