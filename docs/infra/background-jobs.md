# Background jobs

## CMS recurring jobs

CMS deployments update the application's Solid Queue ECS service through
[deploy-ecs.yml](../../.github/workflows/deploy-ecs.yml). Recurring application
jobs are configured in [recurring.yml](../../app/config/recurring.yml) under
`production` (the Rails environment used by deployed workers).

`NscCertificateCheckJob` runs daily at 13:00 UTC using the worker's `HUB_CERT`
or `HUB_CERT_PATH` configuration. It logs certificate status and sends certificate
telemetry and errors to New Relic. Deploy the worker image along with the app
image to activate the schedule.

NSC is supported only in CMS infrastructure. Its client certificates are already
configured there except in prod; prod needs certificate configuration before NSC
can be enabled. An absent certificate is skipped by the daily check.

FDSH enrollment failures increment the New Relic `Custom/NSC/Failure` counter
once per failed enrollment operation, including OAuth, HTTP, timeout, connection,
TLS, and invalid-JSON failures. They also report the original `ApiError` to New
Relic. Successful requests do not increment the counter.

Certificate warnings report `CertificateExpiringSoonError` to New Relic when
expiry is within 30 days (overridable with `NSC_CERT_EXPIRATION_WARNING_DAYS`).
Expired and invalid certificates report `CertificateExpiredError` and
`CertificateInvalidError`. Valid certificates report telemetry without an error.

### Alert verification

Local specs verify the failure counter and error reports, and exercise the
scheduled certificate job with a synthetic expiring certificate. These checks
verify application signals, not live New Relic alert delivery.

Before rollout, verify the existing CMS New Relic conditions select the CMS
application and the `Custom/NSC/Failure` counter and certificate warning errors.
In a CMS nonproduction environment, use synthetic inputs to simulate enough FDSH
failures to breach the configured threshold, and a synthetic certificate within
the warning window. Confirm that each opens the intended New Relic incident and
reaches its configured notification destination, then confirm recovery. Record
the condition names, environment, incident identifiers, and notification results.
Do not replace deployed client certificates to perform this check.

The remaining sections describe the Nava Terraform job infrastructure.

The application may have background jobs that support the application. Types of background jobs include:

* Jobs that occur on a fixed schedule (e.g. every hour or every night) — This type of job is useful for ETL jobs that can't be event-driven, such as ETL jobs that ingest source files from an SFTP server or from an S3 bucket managed by another team that we have little control or influence over.
* Jobs that trigger on an event (e.g. when a file is uploaded to the document storage service). This type of job can be processed by two types of tasks:
  * Tasks that spin up on demand to process the job — This type of task is appropriate for low-frequency ETL jobs **This is the currently the only type that's supported**
  * Worker tasks that are running continuously, waiting for jobs to enter a queue that the worker then processes — This type of task is ideal for high frequency, low-latency jobs such as processing user uploads or submitting claims to an unreliable or high-latency legacy system **This functionality has not yet been implemented**

## Job configuration

Background jobs for the application are configured via the application's `env-config` module. The current infrastructure supports jobs that spin up on demand tasks when a file is uploaded to the document storage service. These are configured in the `file_upload_jobs` configuration.

## How it works

### File Upload Jobs

File upload jobs use AWS EventBridge to listen to "Object Created" events when files are uploaded to S3. An event rule is created for each job configuration, and each event rule has a single event target that targets the application's ECS cluster. The task uses the same container image that the service uses, and the task's configuration is the same as the service's configuration with the exception of the entry-point, which is specified by the job configuration's `task_command` setting, which can reference the bucket and path of the file that triggered the event by using the template values `<bucket_name>` and `<object_key>`.

### Scheduled Jobs

Scheduled jobs use AWS EventBridge to trigger AWS Step Functions jobs on a reoccurring basis. The trigger can use cron, or a rate (hourly, daily, etc) based syntax, via their `schedule_expression`. Similarly to the file upload jobs, the task uses the same container image and configuration, with the exception of the entry-point, which is specified by the job configuration's `task_command` setting. Scheduled jobs can be configured with retries, to trigger multiple jobs in a row, or to run in a certain timezone - although we do not configure any of these settings by default.
