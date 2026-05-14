# Income Report Transmission API Specification [General]


# **Introduction**

This document describes the **Income Report Transmission API Specification**, a method by which income report data can be sent from the Eligibility made easy (Emmy) platform to an agency's systems.

The agency must build an API endpoint that meets this specification and integrates with agency systems to process the income report into the case file for the correct client (those applying for or receiving benefits from an agency).

![api flow diagram](/api-flow.png)

# **API Specification**

The agency-built API should contain one endpoint.

## **POST /api/v1/income-report** (Receive an income report)

This API endpoint is built by the agency and receives an income report record. The endpoint URL can be whatever the agency desires, however, it must include a version number to allow for easy upgrades in the future.

### Request Body – API Fields

| Field Name | Required? | Description | Field Name | Required? | Description |
| :-- | :-- | :-- | :-- | :-- | :-- |
| confirmation_code | Yes | String. Unique code assigned when the report was completed. This is shared with the user and used to debug any errors while processing the report. |  |  |  |
| completed_at | Yes | Date Time (ISO8601). The UTC time when the user completed the report. |  |  |  |
| agency_partner_metadata | Yes | JSON object (See Agency Partner Metadata Object below). |  |  |  |
| income_report | Yes | JSON object (See Income Report Object below). |  |  |  |

### Request Object Type Definitions

#### Agency Partner Metadata Object

The field structure for this object will differ for each agency based on the integration plan for the agency. The fields will include whichever fields are necessary by the agency for indexing the Income Report back into the proper case:

* If agency is using the **Tokenized Link API:** This object will contain all fields initially sent to Emmy when calling the Tokenized Link API.
* If agency is sending users an Emmy **Generic Link:** This object will contain the user-provided values to the agency's indexing data fields.

Sample fields:

| Field Name | Required? | Field Type | Field Name | Required? | Field Type |
| :-- | :-- | :-- | :-- | :-- | :-- |
| case_number | No | String |  |  |  |
| date_of_birth | No | Date String |  |  |  |
| doc_id | Yes | String |  |  |  |

Note

An updated version of this section will be sent separately to the agency during integration calls.

#### Income Report Object

Representation of the user's income report. The subfields are listed below.

| Field Name | Required? | Field Type | Field Name | Required? | Field Type |
| :-- | :-- | :-- | :-- | :-- | :-- |
| has_other_jobs | Yes | Boolean. Whether the user answered that they have additional jobs to report separately from the Emmy product. |  |  |  |
| employments[] | Yes | Array of Employment objects reflected in income report. (See Employment Object below.) |  |  |  |

#### Employment Object

All fields below come from a payroll provider linked by the user. Most fields are optional, and may be set to `null` if unavailable by the payroll provider.

| Field Name | Required? | Field Type | Field Name | Required? | Field Type |
| :-- | :-- | :-- | :-- | :-- | :-- |
| applicant_full_name | Yes | String. Name of user from payroll provider. |  |  |  |
| applicant_ssn | No | String. Client SSN (last 4 digits, if available) rendered as "XXX-XX-1234". |  |  |  |
| applicant_extra_comments | No | String. Applicant-provided comments about the accuracy of the payroll data. |  |  |  |
| employer_name | Yes | String. |  |  |  |
| employer_phone | No | String. |  |  |  |
| employer_address | No | String. |  |  |  |
| employment_status | No | String. One of "employed", "inactive", or "terminated". |  |  |  |
| employment_type | No | String. One of "w2" or "gig". |  |  |  |
| employment_start_date | No | Date (ISO8601) of start of employment, if available. |  |  |  |
| employment_end_date | No | Date (ISO8601) of end of employment, if available. |  |  |  |
| pay_frequency | No | String. Interval of how often the user is paid.The valid values are: daily, weekly, biweekly, semimonthly, monthly, quarterly, variable. |  |  |  |
| compensation_amount | No | Integer. Compensation amount as configured in the payroll provider, in cents. |  |  |  |
| compensation_unit | No | String. Compensation interval. For example, someone earning $13/hour would havecompensation_amount = 1300compensation_unit = "hour"The valid values are: hourly, daily, weekly, biweekly, semimonthly, monthly, annual, salary, per_mile, semiweekly, variable. |  |  |  |
| paystubs[] | Yes | Array of paystub objects representing payments the applicant received. (See Paystub object, below.) |  |  |  |

#### Paystub Object

| Field Name | Required? | Field Type | Field Name | Required? | Field Type |
| :-- | :-- | :-- | :-- | :-- | :-- |
| pay_date | Yes | Date (ISO8601) of paystub. |  |  |  |
| pay_period_start | No | Date (ISO8601) representing the first day of work this paystub includes. |  |  |  |
| pay_period_end | No | Date (ISO8601) representing the last day of work this paystub includes. |  |  |  |
| pay_gross | Yes | Integer representing this paycheck's gross pay, in cents. For example, a paycheck with gross earnings of $123.45 would be represented as 12345. |  |  |  |
| pay_gross_ytd | No | Integer representing the gross pay YTD from the paystub, in cents. |  |  |  |
| pay_net | No | Integer representing this paycheck's net pay after deductions, in cents. |  |  |  |
| hours_paid | No | Float representing a calculation of hours the user was paid for working on this paystub. This includes base hours and overtime. |  |  |  |
| deductions[] | No | Array of deduction objects representing the deductions listed on the paystub. (See Deduction object, below.) |  |  |  |

  

**Deduction Object**

| Field Name | Required? | Field Type | Field Name | Required? | Field Type |
| :-- | :-- | :-- | :-- | :-- | :-- |
| category | Yes | String representing the name of the deduction. |  |  |  |
| tax | Yes | String representing the tax status: "pre_tax", "post_tax", or "unknown" |  |  |  |
| amount | Yes | Integer representing the amount of the deduction in cents (1234 for $12.34) |  |  |  |

# **Environments**

The agency must provide the Emmy team two endpoints: one in a lower environment (for testing) as well as one in a production environment.

| Environment Name | Sample Path | Environment Name | Sample Path |
| :-- | :-- | :-- | :-- |
| Lower | https://dev.your-agency.gov/api/v1/income-report |  |  |
| UAT / Production | https://your-agency.gov/api/v1/income-report |  |  |

The Emmy team will connect our "demo" environment to the agency's lower environment, and the agency's production environment to your production environment.

Each API Environment will have a different API Key for authentication.

# **Authentication / Security**

As sensitive PII data will be included in the API request information, it's important to ensure that our systems are connected securely.

Currently, Emmy does not support private network connections (VPN, network peering, or similar). We will instead rely on encryption provided in-transit via Transport Layer Security (TLS). All API requests will be made via TLS 1.2+.

## IP Block Allowlisting

The IP addresses that Emmy will use to communicate with your application are below. Agencies should ensure these IP addresses are allowlisted in firewalls to ensure greater security.

Note: These differ from the IP addresses used for the Tokenized Link API.

| Environment | IP Addresses | Environment | IP Addresses |
| :-- | :-- | :-- | :-- |
| Demo | 100.28.86.29 |  |  |
| Production | 35.168.67.118 |  |  |

## Signature Verification

Since the API endpoint will be accessible via the internet, the agency system must implement validation to ensure the request originates from the official Emmy system. We will use the agency's **API Key** (for the Tokenized Link API) as a secret key for API signature validation. If the agency does not have an API key, or does not use the Tokenized Link API, we will generate an API key specific for this purpose.

Every API request from Emmy will be verified with a pair of HTTP headers which comprise a signature:

| HTTP Header Name | Description | HTTP Header Name | Description |
| :-- | :-- | :-- | :-- |
| X-Emmy-Timestamp | Seconds since Unix Epoch |  |  |
| X-Emmy-Signature | Calculated signature based on the algorithm below. |  |  |

 The signature for a request can be verified with the following Python pseudocode:

```
Turn on wrapCopy as textdef compute_signature(api_key: str, timestamp: str, request_body: bytes) -> str: signature_payload = "v1:#{timestamp}:#{request_body}" return HMAC("SHA512", api_key, signature_payload) def verify_signature(request, api_key: str) -> bool: signature = request.headers.get("X-Emmy-Signature", "") timestamp = request.headers.get("X-Emmy-Timestamp", "") request_body = request.get_data() if abs(time.time() - int(timestamp)) > 300: print("System clocks out of sync, or possible replay attack.") return false return hmac.compare_digest(signature, compute_signature(request, timestamp))
```

# **Error Handling**

It's imperative for Emmy to know whether an income report was correctly received by the agency. To that end, the HTTP status code of the response will inform Emmy whether the report was successful.

Agencies must implement semantic HTTP statuses representing the success of the webservice receiving the request. The specific HTTP status codes used can be determined by the agency based on what is feasible to support. The only semantics Emmy relies upon are that a "200 OK" status be returned when the request is successful, and a 400+ status code be used when there is an error.

| HTTP Status Code | Definition | Action | HTTP Status Code | Definition | Action |
| :-- | :-- | :-- | :-- | :-- | :-- |
| 200 OK | The income report was successfully received by the agency's system. | Mark successful. |  |  |  |
| 401 Unauthorized | The X-Emmy-Signature header verification failed. | Attempt retry. |  |  |  |
| 500 Internal Server Error | There was a system error while processing the request. | Attempt retry. |  |  |  |

In addition to these statuses, we encourage agency web servers to reply with semantic HTTP statuses such as 400 Bad Request, 404 Not Found, 408 Timeout, 413 Payload Too Large, 429 Too Many Requests, and 502 Gateway Timeout according to their built-in web server logic. This will greatly help triaging errors should they arise. Regardless of the error status code, Emmy will retry according to the logic below.

## Retry Logic

If Emmy receives an error status response, Emmy will automatically retry delivering the same income report two additional times over the next 30 seconds.

If the report is not successfully delivered on that third attempt, it will go to an error queue within Emmy and we will triage the issue in partnership with the agency's technical team.