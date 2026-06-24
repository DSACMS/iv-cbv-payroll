# PDF Document Transmission API Specification [General]


# **Introduction**

This document describes the API implemented by a state agency to receive PDF document images from the Eligibility made easy (Emmy) platform. This API is an alternative to other file delivery methods, such as SFTP, S3, or Shared Email.

The agency must build this API endpoint and ensure that documents are ingested into the correct case within the eligibility management system.

For agencies which have also implemented the **Income Report API** to receive a JSON representation of the income data, the Document Transmission API will be called after the Emmy platform receives a successful response from the Income Report API.

# **Environments**

The agency must provide the Emmy team three endpoints:

| Environment Name | Emmy Environment | Sample Path | Environment Name | Emmy Environment | Sample Path |
| :-- | :-- | :-- | :-- | :-- | :-- |
| Lower | Dev | https://dev.your-agency.gov/api/v1/income-report |  |  |  |
| UAT | Demo | https://uat.your-agency.gov/api/v1/income-report |  |  |  |
| Production | Production | https://your-agency.gov/api/v1/income-report |  |  |  |

Each API Environment will have a different keys for authentication.

# **API Specification**

## **POST /api/v1/documents** (Receive an Income Report PDF)

This API endpoint must be built by the agency and will receive a PDF image of an income report. The endpoint path is suggested to be /api/v1/documents, but the agency can suggest an alternative path so long as it contains a version number.

The endpoint must only accept requests over TLS.

### Request Headers

| Header Name | Required? | Description | Header Name | Required? | Description |
| :-- | :-- | :-- | :-- | :-- | :-- |
| X-IVAAS-Timestamp | Yes | Seconds since the Unix epoch (used to verify the request signature) |  |  |  |
| X-IVAAS-Signature | Yes | Calculated signature based on the request body.See the documentation for the Income Report API for a description of this algorithm. |  |  |  |
| X-IVAAS-Confirmation-Code | Yes | Confirmation code of the submitted document, for example ("LALDH00100001") |  |  |  |

Additional headers used for authentication may be requested by an agency (for example API keys).

### Request Body

The PDF will be sent in the body of the request. The request will be sent with appropriate values for standard HTTP headers:

* Content-Type: application/pdf
* Content-Length: (Size of PDF in bytes)

The PDF will not be compressed.

### Sample Request

```
Turn on wrapCopy as textPOST /api/v1/income-report HTTP/1.1 Host: your-agency.gov X-IVAAS-Timestamp: 1764709880 X-IVAAS-Signature: 77cdb11cfad51afd5b5d5eb8aa1b7735b1578202e479bf82eb36d38ac32c1f0263761fdc9c962e78a367d7e6bc841c8dbc97dcc5dc384cf0c4e36fe3ea3ec5e7 X-IVAAS-Confirmation-Code: LALDH00100001 Content-Type: application/pdf Content-Length: 12345 [pdf contents here]
```

# **Error Handling**

It's imperative for Emmy to know whether an income report was correctly received by the agency. To that end, the HTTP status code of the response will inform Emmy whether the report was successful.

Agencies must implement semantic HTTP statuses representing the success of the webservice receiving the request. The specific HTTP status codes used can be determined by the agency based on what is feasible to support. The only semantics Emmy relies upon are that a "200 OK" status be returned when the request is successful, and a 400+ status code be used when there is an error.

| HTTP Status Code | Definition | Action | HTTP Status Code | Definition | Action |
| :-- | :-- | :-- | :-- | :-- | :-- |
| 200 OK | The income report PDF was successfully received by the agency's system. | Mark successful. |  |  |  |
| 401 Unauthorized | The X-IVAAS-Signature header verification failed. | Attempt retry. |  |  |  |
| 500 Internal Server Error | There was a system error while processing the request. | Attempt retry. |  |  |  |

In addition to these statuses, we encourage agency web servers to reply with semantic HTTP statuses such as 400 Bad Request, 404 Not Found, 408 Timeout, 413 Payload Too Large, 429 Too Many Requests, and 502 Gateway Timeout according to their built-in web server logic. This will greatly help triaging errors should they arise. Regardless of the error status code, Emmy will retry according to the logic below.

## Retry Logic

If Emmy receives an error status response, Emmy will automatically retry delivering the same income report up to five additional times over the next 10 minutes.

If the report is not successfully delivered on the last attempt, it will go to an error queue within Emmy and we will triage the issue in partnership with the agency's technical team.