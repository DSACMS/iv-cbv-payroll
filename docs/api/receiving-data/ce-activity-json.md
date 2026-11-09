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

`agency_partner_metadata` identifies the applicant in the agency's records.
When no individual_id was supplied, the webhook includes the agency's V1 metadata field set. When an individual_id was supplied during V2 invitation creation, it includes the agency's V2 metadata field set, including that exact ID. Unavailable values are sent as null; individual_id is omitted when it was not supplied. Dates of birth are serialized as YYYY-MM-DD, rather than echoed from the invitation request.

For employment, `employment_type` is populated only for Argyle-sourced records
as `w2` or `gig`; self-attested and Pinwheel entries retain the field as `null`. To identify
self-employment across both sources, use
`employment_type == "gig" OR is_self_employed == true`.

For NSC education, `enrollment_status` retains NSC's mapped status. NSC `Y` is
reported as `"enrolled"`: it confirms enrollment without specifying a level.
Partially self-attested entries include `supplemental_enrollment_status` for the
applicant's supplied level: `full_time`, `half_time`, `less_than_half_time`, or
`unknown` (the applicant is unsure). It is `null` for other NSC statuses or when
no supplemental level was supplied.

The `credit_hours` and `hours` fields contain applicant-reported term credits
when NSC reports `less_than_half_time`, or when NSC reports `enrolled` and the
supplemental level is `less_than_half_time` or `unknown`. Fractions and zero are
preserved. Reporting no classes for an `enrolled` term produces `0` in both
credit fields and `null` in `supplemental_enrollment_status`. Credits are `null`
for supplemental `full_time` or `half_time`, or when not reported.

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
  "schema_version_received": "1.0.0"
}
```

Emmy currently checks the HTTP status and does not validate this response body.

## Request body

The request body uses the `CeActivityReport` OpenAPI model. Expand its properties
and linked models in the reference for field descriptions, required and nullable
fields, monthly reporting rules, and the employment and education variants.
The generated request example shows a complete report with all activity types.

# **Design Principles**

| Design | Description                                                                                                                                                                                        |
| :-- |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Legacy System Tolerant Design | Fields should only be added to the spec at any time without breaking existing integrations. Fields are only removed in major version releases. Fields must be introduced in minor version releases |
| Soft required fields | Fields that should be present but may not always be available from upstream providers are not marked as required, and denote `null` as an acceptable value.                                        |
