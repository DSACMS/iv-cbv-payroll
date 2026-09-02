# Community Engagement Activity Report Transmission API Specification [General]

# **Introduction**

This document describes the **Community Engagement (CE) Activity Report Transmission API Specification**, a method by which CE activity data can be sent from the Eligibility made easy (Emmy) platform to an agency's systems.

The agency must build an API endpoint that meets this specification and integrates with agency systems to process the activity report into the case file for the correct client.

This revision covers the **self-attested activity types only**: `community_service` and `work_program`. Education and employment activities are not yet transmitted; they will be added additively in a later revision.

# **API Specification**

The agency-built API should contain one endpoint.

## **POST /api/v1/ce-activity-report** (Receive a CE activity report)

This API endpoint is built by the agency and receives one CE activity report record. The endpoint URL can be whatever the agency desires, however, it must include a version number to allow for easy upgrades in the future.

The machine-readable JSON Schema for the request body is available at [schemas/ce-activity-report-2026-09-01.json](schemas/ce-activity-report-2026-09-01.json). A complete sample request body is available at [samples/ce-activity-report.json](samples/ce-activity-report.json).

### Request Headers

The same signing scheme used by the [Income Report Transmission API](income-report.md) applies.

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
| agency | Yes | JSON object (See Agency Object below). |
| ce_report | Yes | JSON object (See CE Report Object below). |

### Request Object Type Definitions

#### Agency Object

The field structure for this object will differ for each agency based on the integration plan for the agency, exactly as the `agency_partner_metadata` object does in the [Income Report Transmission API](income-report.md). It contains whichever fields the agency needs to index the report back into the proper case, plus `extended_attributes`.

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
| individual | Yes | Object. `name.first`, `name.middle`, `name.last`, plus `extended_attributes`. |
| documents | Yes | Array of Document objects. All supporting documents uploaded for the activities in this report. |
| activities | Yes | Object. Activity types at the top level; within each type, months keyed as `YYYY-MM`. |

#### Document Object

| Field Name | Required? | Field Type |
| :-- | :-- | :-- |
| document_id | Yes | String. Identifier unique within this report, referenced from each activity's `document_ids`. |
| document_name | Yes | String. The filename the document is transmitted under. |
| file_type | Yes | String. The file extension, without the leading dot. |

Documents themselves are transmitted separately by the document transmission integration; this array describes what to expect.

#### Activities Object

Keys are activity types. Each value is an object keyed by month (`YYYY-MM`), whose value is an array of activity entries reported for that month. A month with no reported activity is omitted; an activity type with no activities is an empty object.

An activity that spans several months appears once under each month, carrying that month's hours.

#### Activity Entry – Fields Common to All Types

| Field Name | Required? | Description |
| :-- | :-- | :-- |
| type | Yes | String (enum). `community_service` or `work_program`. |
| month | Yes | String (`YYYY-MM`). The calendar month the reported hours apply to. Repeats the key of the enclosing object. |
| hours | Yes | Decimal (10,2). Hours reported for this activity in the enclosing month. May be `0`. |
| data_source | Yes | String (enum). Always `self_attested` for these two activity types. |
| document_ids | Yes | Array of `document_id` values from the `documents` array. |
| street_address, street_address_line_2, city, state, zip_code | No | String or null. Address of the organization. |
| additional_comments | No | Text or null. Optional free-text comments the applicant added at the review step. |
| extended_attributes | Yes | Object. Free-form; may be empty. |

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

# **Design Principles**

| Design | Description |
| :-- | :-- |
| Tolerant Reader | Systems should accept payloads that contain unknown or extra fields without rejecting them. Only a minimal set of fields are truly required. |
| Additive-only schema evolution | New fields can be added to the spec at any time without breaking existing integrations. Fields are only removed in major version releases. |
| Soft required fields | Fields that should be present but may not always be available from upstream providers are not marked as required, and denote `null` as an acceptable value. |
| `extended_attributes` | Any unrecognized fields from upstream providers are captured in a free-form `extended_attributes` object rather than being stripped or rejected. An empty object is valid. |
