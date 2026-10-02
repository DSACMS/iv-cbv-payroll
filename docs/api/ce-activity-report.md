# Community Engagement Activity Report Transmission API Specification [General]

## Model

This document describes the **Community Engagement (CE) Activity Report Transmission API Specification**, a method by which CE activity data can be sent from the Eligibility made easy (Emmy) platform to an agency's systems.

The agency must build an API endpoint that meets this specification and integrates with agency systems to process the activity report into the case file for the correct client.

This revision covers `community_service`, `work_program`, and `employment`. Employment includes self-attested work and payroll data from linked Argyle or Pinwheel accounts. Education activities will be added additively in a later revision.

## Transmission

The agency-built API should contain one endpoint.

## **POST /api/v1/ce-activity-report** (Receive a CE activity report)

This API endpoint is built by the agency and receives one CE activity report record. The endpoint URL can be whatever the agency desires, however, it must include a version number to allow for easy upgrades in the future.

The complete `CeActivityReport` model is published in the generated
[OpenAPI reference](README.md), along with component models for the report,
review period, documents, activity types, and payroll details. It is a standalone
model: this outbound report is not an Emmy API operation. The schema's example
comes from the tested serializer and includes community service, work programs,
linked payroll, self-employment, and unpaid work.

### Request Headers

The same signing scheme used by the Income Report Transmission API applies.

| Header | Description |
| :-- | :-- |
| `X-IVAAS-Timestamp` | Unix timestamp the request was signed at. |
| `X-IVAAS-Signature` | HMAC-SHA512 hexdigest of `"<timestamp>:<request body>"`, keyed with the agency's API key. |
| `X-IVAAS-Confirmation-Code` | The report's confirmation code, repeated for convenience. |

Any additional headers the agency requires (for example an API gateway key) can be configured per-agency and are sent verbatim.

### Response Body

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

### Request Body – Root Fields

| Field Name | Required? | Description |
| :-- | :-- | :-- |
| schema_version | Yes | String (semver). Version of the CE compliance spec this payload conforms to. |
| confirmation_code | Yes | String. Unique code assigned when the report was completed. This is shared with the user and used to debug any errors while processing the report. |
| completed_at | Yes | Date Time (ISO8601). The UTC time when the user completed the report. |
| agency_partner_metadata | Yes | JSON object (See Agency Partner Metadata Object below). |
| ce_report | Yes | JSON object (See CE Report Object below). |

### Request Object Type Definitions

#### Agency Partner Metadata Object

The field structure for this object will differ for each agency based on the integration plan for the agency, exactly as the `agency_partner_metadata` object does in the Income Report Transmission API. It contains whichever fields the agency needs to index the report back into the proper case.

Sample fields:

| Field Name | Required? | Field Type |
| :-- | :-- | :-- |
| case_number | Agency-specific | String |
| date_of_birth | Agency-specific | Date String |
| doc_id | Agency-specific | String |

#### CE Report Object

| Field Name | Required? | Field Type |
| :-- | :-- | :-- |
| review_period | Yes | Object. The full date range this CE compliance determination covers. `start_month` and `end_month` are both `YYYY-MM` strings. |
| documents | Yes | Array of Document objects. All supporting documents uploaded for the activities in this report. |
| activities | Yes | Object. Activity types at the top level; within each type, months keyed as `YYYY-MM`. |

#### Document Object

| Field Name | Required? | Field Type |
| :-- | :-- | :-- |
| document_id | Yes | String. Identifier based on the Emmy Active Storage attachment ID, referenced from each activity's `document_ids`. |
| document_name | Yes | String. The filename the document is transmitted under. |
| file_type | Yes | String. The file extension, without the leading dot. |

Documents themselves are transmitted separately by the document transmission integration; this array describes what to expect.

#### Activities Object

Keys are activity types. Each value is an object keyed by month (`YYYY-MM`), whose value is an array of activity entries reported for that month. A month with no reported activity is omitted; an activity type with no activities is an empty object.

An activity that spans several months appears once under each month, carrying that month's hours.

#### Self-attested Activity Entry – Common Fields

| Field Name | Required? | Description |
| :-- | :-- | :-- |
| type | Yes | String (enum). `community_service`, `work_program`, or `employment`. |
| month | Yes | String (`YYYY-MM`). The calendar month the reported hours apply to. Repeats the key of the enclosing object. |
| hours | Yes | Decimal (10,2). Hours reported for this activity in the enclosing month. May be `0`. |
| data_source | Yes | String (enum). `self_attested` for manually reported activities. Linked payroll employment uses `validated`. |
| document_ids | Yes | Array of `document_id` values from the `documents` array. |
| street_address, street_address_line_2, city, state, zip_code | No | String or null. Address of the organization. |
| additional_comments | No | Text or null. Optional free-text comments the applicant added at the review step. |

#### community_service Additional Fields

| Field Name | Required? | Description |
| :-- | :-- | :-- |
| organization_name | Yes | String. Full, official name of the community service organization. |
| coordinator_name | No | String or null. Coordinator/supervisor the applicant worked most closely with. |
| coordinator_email | No | String or null. |
| coordinator_phone_number | No | String or null. |

#### work_program Additional Fields

| Field Name | Required? | Description |
| :-- | :-- | :-- |
| organization_name | Yes | String. Name of the organization or provider running the work/training program. |
| program_name | Yes | String. Full name of the work program. |
| contact_name | No | String or null. |
| contact_email | No | String or null. |
| contact_phone_number | No | String or null. |

#### employment – Self-attested Work

Each published employment activity appears once per reported month, including months with zero hours or income. Draft activities are excluded. The common self-attested fields above apply, including address components, comments, hours, and supporting document IDs.

| Field Name | Required? | Description |
| :-- | :-- | :-- |
| employer_name | Yes | String. Name of the employer or business. |
| employer_address | No | String or null. Combined employer address. The individual address fields are also supplied. |
| employment_type | Yes | `w2` for paid work, `self_employed` for paid self-employment, or `unpaid` for unpaid or in-kind work. |
| is_self_employed | Yes | Boolean. Whether the applicant marked the work as self-employment. |
| contact_name, contact_email, contact_phone_number | No | String or null. Employer contact details; null for self-employment. |
| gross_income | Yes | Number. Self-attested gross income for this month in **dollars**, preserving decimal amounts. |

#### employment – Linked Payroll

Only published, successfully synchronized payroll accounts are included. Each employer appears once in each month in which it has a paycheck in the review period. Paychecks are grouped by `pay_date`, even when their work period falls in another month. Undated paychecks and paychecks outside the review period are omitted. Employers with no dated paychecks in the review period have no monthly entry.

The employment and paystub fields use the [Income Report API format](schemas/income-report-2026-06-18.json), including masked SSNs, applicant comments, employment dates and status, compensation, deductions, and itemized gross pay. Payroll money values are in **cents**. Nullable provider fields remain null, and missing gross pay uses the income report's zero fallback. Payroll hours appear in each paystub's `hours_paid`; there is no calculated employment-level `hours` field.

These CE fields supplement the income employment object:

| Field Name | Required? | Description |
| :-- | :-- | :-- |
| type | Yes | `employment`. |
| month | Yes | `YYYY-MM`, matching the enclosing month. |
| data_source | Yes | `validated` for both Argyle and Pinwheel. |
| document_ids | Yes | Empty array for linked payroll. Self-attested documents are referenced from their own activities. |

Employment follows the September 4 specification's JSON examples: `has_other_jobs` and `income_summary` are omitted. The existing CE envelope, including `review_period`, is preserved. A failed payroll fetch fails transmission so the job can retry instead of sending a partial report.

#### Validating the Model

From `app/`, run the contract specs or build the complete API reference:

```bash
rtk rbenv exec ruby bin/rspec spec/services/transmitters/activity_json_transmitter_spec.rb spec/openapi
rtk proxy env RAILS_ENV=test rbenv exec bundle exec rake api_docs:build
```

The build validates the OpenAPI model and its generated example. Contract tests
also exercise Argyle's Bob, Joe, and Kim sandbox fixtures and a mixed report with
Pinwheel payroll, self-employment, and unpaid work. Tests make no live payroll or
agency requests. Product acceptance and live Launcher testing remain separate
checks before merge.

# **Design Principles**

| Design | Description |
| :-- | :-- |
| Tolerant Reader | Systems should accept payloads that contain unknown or extra fields without rejecting them. Only a minimal set of fields are truly required. |
| Additive-only schema evolution | New fields can be added to the spec at any time without breaking existing integrations. Fields are only removed in major version releases. |
| Soft required fields | Fields that should be present but may not always be available from upstream providers are not marked as required, and denote `null` as an acceptable value. |
