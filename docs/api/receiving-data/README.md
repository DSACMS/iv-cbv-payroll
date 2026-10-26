# Receiving data from the Emmy Platform

## Overview

Your agency can receive data from Emmy through webhooks as an alternative to
SFTP, email, or S3 delivery. With webhook delivery, Emmy sends HTTP POST requests
to HTTPS endpoints hosted by your agency, so the received data can be added to
the correct applicant case.

Depending on your integration, your agency can receive:

- **Income Reports (JSON):** structured income and payroll data.
- **CE Activity Reports (JSON):** community engagement activities, including
  employment, education, community service, and work programs.
- **Documents:** income report PDFs and supporting activity documents, sent as
  raw file bytes with their MIME type.

Arrange the delivery methods, receiver URLs, and any additional headers with
the Emmy team during onboarding. Your receiver verifies each request's
signature, processes the report or document, and returns an HTTP response.
The sections below describe the delivery flow, shared signing and retry
behavior, and the payloads your endpoints receive.
