---
name: iac-compliance
description: >
  Perform a comprehensive pre-commit IaC compliance review on uncommitted
  infrastructure-as-code changes (Terraform, CloudFormation, Bicep, Pulumi,
  Ansible, Kubernetes manifests, Helm charts, CDK, and similar). Checks staged
  changes against CMS ARS 5.1 and NIST SP 800-53 Rev 5 controls that are
  directly enforceable through IaC. Blocks on critical, high, and medium
  findings; warns on low. Use whenever an IaC compliance review is requested,
  when running as a pre-commit hook, or any time uncommitted infrastructure
  changes need compliance validation before they enter the repository. Only
  report findings of low severity or above.
---

# IaC Compliance Skill

A focused, pre-commit compliance review of infrastructure-as-code changes
against **CMS ARS 5.1** (which incorporates and tailors **NIST SP 800-53
Rev 5**) for the controls that can be verified by inspecting IaC directly.

Runs on **staged (uncommitted) changes only** by default — fast, targeted, and
actionable.

This skill is invoked by a pre-commit hook dispatcher
(`.skills/iac-compliance/scripts/iac-compliance-hook-dispatcher.sh`)
which selects an AI assistant based on the `AI_REVIEW_TOOL` environment
variable (`claude` | `codex` | `copilot`). The skill instructions are
identical across all three assistants; only the invoking CLI differs.

This file (`.skills/iac-compliance/SKILL.md`) is the **canonical** copy. Each
developer's chosen AI tool reads either this file or a byte-identical derived
copy under `.claude/`, `.codex/`, or `.github/copilot/`, depending on what
`scripts/sync-skills.sh` produced for their `AI_REVIEW_TOOL` setting.

---

## Execution Overview

1. **Collect changes** — staged diff by default; `--against <ref>` for ad-hoc reviews
2. **Detect IaC type** — identify tooling from file extensions and context
3. **Load targeted context** — pull in the minimum related files needed for accurate assessment
4. **Run control checks** — work through each applicable control family
5. **Report** — low/medium/high/critical findings only
6. **Emit result marker** — exactly one of `<<<AI_REVIEW_RESULT:PASS|WARN|BLOCK>>>`

**Severity-to-result mapping:**
| Severity contributing to report | Result |
|---|---|
| Any Critical, High, or Medium | BLOCK |
| Only Low | WARN |
| None | PASS |

---

## Step 1 — Collect Changes

By default, review the **staged diff**:

```bash
git diff --cached --unified=5      # full content of staged changes
git diff --cached --name-only      # list of staged file paths
```

If the dispatcher passed an `--against <ref>` argument, the changes to review
are the diff between that ref and HEAD. The dispatcher communicates this via
the `AI_REVIEW_AGAINST` environment variable:

```bash
if [ -n "$AI_REVIEW_AGAINST" ]; then
  git diff "$AI_REVIEW_AGAINST" HEAD --unified=5
  git diff "$AI_REVIEW_AGAINST" HEAD --name-only
fi
```

If the relevant diff is empty, exit cleanly:
> "No changes to review. Skipping."

If none of the changed files are recognisable IaC (see file types below), note
this and exit cleanly:
> "No IaC files detected in changes. Skipping iac-compliance review."

**Recognised IaC file patterns:**
- Terraform: `.tf`, `.tfvars`, `.tf.json`
- CloudFormation: `*.template.json`, `*.template.yaml`
- Bicep: `*.bicep`, `*.bicepparam`
- Pulumi: `Pulumi.yaml`, `Pulumi.*.yaml`, `*.pulumiproject`
- Ansible: `requirements.yml` plus `*.yml`/`*.yaml` under `roles/` or `playbooks/`
- Kubernetes: any YAML containing both `apiVersion:` and `kind:`
- Helm: `Chart.yaml`, `values.yaml`, `templates/`
- CDK: `cdk.json`, `app.py`/`app.ts` when paired with `cdk.json`
- Terragrunt / Packer: `*.hcl`

---

## Step 2 — Detect IaC Type and Load Targeted Context

Identify which IaC tool(s) are in use based on file extensions and directory
structure. This determines which control checks apply (e.g., AWS-specific
checks only apply when Terraform or CloudFormation targets AWS).

**Load these context files if not already in the diff (limit: ≤ 15 files):**

| Context file | Why it matters |
|---|---|
| `terraform.tfvars`, `*.auto.tfvars`, `variables.tf` | Resolves variable references in the diff; needed to assess actual values |
| `backend.tf`, `versions.tf` | State backend config; provider version constraints |
| `data.tf` or files containing `data "` blocks | Data sources that feed into changed resources |
| Module `main.tf` when changed resource calls a local module | Understand what the module provisions |
| `Chart.yaml`, `values.yaml` for changed Helm templates | Chart metadata and default values |
| `kustomization.yaml` for changed Kubernetes manifests | Overlay context |
| `cdk.json`, shared stack constructs referenced by the diff | CDK context |
| Existing IAM policy JSON files referenced by changed resources | Assess policy permissions in full |
| Existing security group or network ACL rules that the diff modifies | Understand cumulative network exposure |

Do **not** load: entire module registries, provider plugins, lock files
(`.terraform.lock.hcl`), generated plan files, test fixtures, or documentation.

---

## Step 3 — IaC Compliance Control Checks

Apply the control checks below to the diff and loaded context. Skip
categories that have no plausible attack surface in the changed code (e.g.,
skip encryption-at-rest checks if only a DNS record changed). Be explicit
about what was skipped and why.

For each control reference: **NIST SP 800-53 Rev 5 ID** | **CMS ARS 5.1
family** — both use identical control identifiers, since ARS is a tailored
overlay of NIST 800-53.

---

### AC — Access Control

**AC-2 | Account Management**
- IAM users, roles, groups, or service accounts created or modified without a
  description, tags, or clear purpose attribute
- IAM users with console access but no MFA requirement configured
- Shared/generic account names (`admin`, `root`, `shared`, `common`) in new
  resource definitions

**AC-3 | Access Enforcement / Least Privilege**
- IAM policies with `"Action": "*"` or `"Action": ["*"]` (wildcard actions)
- IAM policies with `"Resource": "*"` without a scoping `Condition` block
- `"Effect": "Allow"` on `sts:AssumeRole` without `Condition` constraints
- IAM roles granted `AdministratorAccess` or equivalent managed policy
- S3 bucket policies granting `s3:*` to `"Principal": "*"` (public write)
- Lambda execution roles with `iam:PassRole` and `"Resource": "*"`

**AC-4 | Information Flow Enforcement**
- Security groups or NACLs allowing inbound `0.0.0.0/0` or `::/0` on:
  - SSH (TCP 22), RDP (TCP 3389) — always Critical
  - Database ports: MySQL/Aurora (3306), PostgreSQL (5432), MongoDB (27017),
    Redis (6379), Elasticsearch (9200/9300), Cassandra (9042) — always High
  - All traffic (`-1` / protocol `all`) — always Critical
- VPC peering or Transit Gateway attachments with unrestricted routing
- ECS/EKS tasks with `hostNetwork: true` or `network_mode = "host"`

**AC-17 | Remote Access**
- Bastion hosts or jump boxes exposed on `0.0.0.0/0` without IP restriction
- VPN endpoints created without certificate-based authentication
- SSM Session Manager not used as the sole remote access method (flag if SSH
  security groups are opened to wide CIDRs instead)

**AC-22 | Publicly Accessible Content**
- S3 buckets without `block_public_acls = true`, `block_public_policy = true`,
  `ignore_public_acls = true`, `restrict_public_buckets = true`
- CloudFront distributions without origin access control/identity
- EC2 instances or load balancers in public subnets without documented justification
- RDS instances with `publicly_accessible = true`
- Elasticsearch/OpenSearch domains with `network_config` set to public

---

### AU — Audit and Accountability

**AU-2 / AU-3 | Audit Events and Content**
- CloudTrail trail disabled, single-region only, or with `is_multi_region_trail = false`
- CloudTrail log file validation disabled (`enable_log_file_validation = false`)
- S3 server access logging disabled on buckets containing sensitive data
  (inferred from bucket name patterns: `logs`, `audit`, `data`, `phi`, `pii`, `backup`)
- VPC Flow Logs not enabled on new VPCs
- EKS control plane logging disabled (missing `enabled_cluster_log_types`)
- RDS enhanced monitoring disabled (`monitoring_interval = 0`)
- CloudFront access logging disabled

**AU-9 | Protection of Audit Information**
- CloudTrail logs delivered to an S3 bucket without server-side encryption (KMS)
- CloudWatch Log Groups without a retention period set (`retention_in_days` absent or 0)
- CloudWatch Log Groups without KMS encryption when they contain sensitive log streams

**AU-11 / SI-11 / AC-23 | Log content discipline (PHI/PII leak prevention at the IaC layer)**

The application-code side of this concern lives in `.skills/code-security/
SKILL.md` § 3A.1 (Logging Hygiene). At the IaC layer, the equivalent
risk is provisioning logging infrastructure that **captures sensitive
data by configuration** — independent of what the application code chooses
to log. HIPAA **§ 164.502(b)** (Minimum Necessary) applies to logs as
much as to APIs: a log sink that records full request bodies on a
PHI-handling service is a HIPAA control failure even if no individual
developer "wrote" the leak. Flag the following:

- **API Gateway / ALB / NLB / CloudFront access logging** enabled on a
  route that exposes identifiers in the path or query string (`/api/
  beneficiary/{mbi}/claims`, `?ssn=...`, `?mbi=...`). Access logs capture
  the full request URI by default. Required mitigations: opaque IDs in
  URLs (preferred); or `access_log_settings` / `logging_config` configured
  to redact / omit the path component; or move the access-log destination
  to a stricter sink (see below). **NIST AC-23, AU-11.**
- **API Gateway stage logging at `INFO` / `DEBUG`** (`data_trace_enabled
  = true`, `logging_level = "INFO"` and above) on PHI-handling APIs — the
  full request and response payload is written to CloudWatch Logs. Allow
  only `ERROR` in production unless paired with an explicit redaction
  layer. **NIST SI-11, AU-3, HIPAA § 164.312(b).**
- **Lambda functions** without `LOG_LEVEL` pinned, or with environment
  variables like `DEBUG=true`, on PHI-handling functions — Lambda's
  default `print()` capture sends everything to CloudWatch. **NIST AU-3.**
- **CloudWatch Logs Insights / subscription filters** that forward logs
  to a downstream sink (Kinesis, OpenSearch, third-party SIEM, Splunk,
  Datadog) **without** a redaction processor in the path. The downstream
  sink often has weaker access controls than the original log group.
  **NIST AU-9, AC-3.**
- **S3 server access logs** on PHI buckets written to a target bucket
  that itself lacks: encryption (`server_side_encryption_configuration`),
  public-access blocks, and an Object Lock / retention policy distinct
  from the source bucket's. Access logs include full object keys —
  which often encode patient/beneficiary identifiers. **NIST AU-9, SC-28.**
- **VPC Flow Logs / Route 53 Resolver Query Logs** routed to a shared
  log bucket without separate access controls when traffic includes
  PHI-bearing internal services (DNS query logs leak service names that
  may include MBI hashes; flow logs leak source/dest pairs useful for
  re-identification). **NIST AU-9, AC-23.**
- **CloudTrail data events** enabled on S3 buckets / DynamoDB tables /
  Lambda functions that hold PHI without scoping `data_resource` to
  exclude object-key / partition-key fields that carry identifiers.
  CloudTrail records the resource ARN, which for S3 includes the object
  key. **NIST AU-9, HIPAA § 164.312(b).**
- **APM / observability provisioning** (Datadog, New Relic, X-Ray,
  OpenTelemetry collectors) configured with sampling that captures full
  span attributes / request headers on PHI-handling services. Flag the
  IaC resource that wires up the agent without an attribute filter or
  scrubber. **NIST SI-11, AC-23.**
- **Audit-log retention shorter than HIPAA's 6-year requirement**
  (§ 164.316(b)(2)(i)) on log groups / S3 buckets storing access-audit
  records for ePHI systems. **NIST AU-11, HIPAA § 164.316(b).**
- **Co-mingled application logs and audit logs** — a single CloudWatch
  log group receiving both application output and § 164.312(b) audit
  events. The audit stream needs stricter retention, access control, and
  KMS scope than the application stream. **NIST AU-9, AC-6.**

For each finding, cite the AU- / SI- / AC-family control ID (and the CMS
ARS 5.1 tailoring when it differs) and recommend the structural fix —
typically a separate, KMS-encrypted, access-controlled audit-sink
resource plus a redaction layer (subscription filter or Firehose
transform) on the application-log path. The remediation should be a
new / modified IaC resource, so use the `` ```hcl `` (or appropriate)
fence rather than `` ```suggestion ``.

---

### CM — Configuration Management

**CM-2 | Baseline Configuration**
- Resources provisioned with no tags, or missing required tags:
  `Environment`, `Owner` (or `Team`), `Project`, `CostCenter` — flag absence
  of two or more of these as Medium; all missing as High
- Hardcoded AMI IDs without a comment explaining their source and purpose
- Hardcoded IP addresses for internal services (should be data source lookups)

**CM-6 | Configuration Settings**
- `deletion_protection = false` on RDS, Aurora, Elasticsearch, or DynamoDB
  tables in non-development environments (inferred from `Environment` tag or
  workspace name)
- `force_destroy = true` on S3 buckets in non-development environments
- Kubernetes containers running as root (`runAsNonRoot: false` or absent;
  `runAsUser: 0`)
- Kubernetes containers with `privileged: true`
- Kubernetes containers with `allowPrivilegeEscalation: true` or absent
- Docker/container images tagged `latest` rather than a pinned digest or
  explicit version tag

**CM-7 | Least Functionality**
- Unused or unnecessary ports opened in security groups beyond what is required
- Lambda functions with `reserved_concurrent_executions` unset and no throttling
- ECS tasks with all Linux capabilities (`add: ["ALL"]`)
- Kubernetes `hostPID: true` or `hostIPC: true`

**CM-8 | System Component Inventory**
- Resources of significant scope (VPCs, subnets, RDS clusters, EKS clusters,
  WAF web ACLs) provisioned without a `Name` tag or `description` field
- Terraform modules used without pinned `version` constraints (using `source`
  from a registry without `version =`)

---

### CP — Contingency Planning

**CP-9 | System Backup**
- RDS instances with `backup_retention_period = 0` or not set
- RDS instances with `skip_final_snapshot = true` in non-development environments
- DynamoDB tables without point-in-time recovery enabled
  (`point_in_time_recovery { enabled = true }`)
- EBS volumes not included in a Backup plan (flag if `aws_backup_selection` is
  absent and significant EC2 resources are being added)

---

### IA — Identification and Authentication

**IA-2 | Multi-Factor Authentication**
- IAM user resources without an associated `aws_iam_virtual_mfa_device` or
  IAM policy requiring MFA via Condition block
- Cognito user pools without MFA enabled (`mfa_configuration = "OFF"`)
- AWS SSO/IAM Identity Center permission sets granting console access without
  `RequireMFA` condition

**IA-5 | Authenticator Management**
- IAM access keys created directly in IaC for human users (vs. roles)
- Hardcoded passwords in RDS, ElastiCache, or MSK resources
  (flag `password =` or `master_password =` set to a literal string)
- AWS Secrets Manager or SSM Parameter Store not used for secrets injection
- KMS key rotation disabled (`enable_key_rotation = false`)
- ACM certificates with expiry monitoring missing (no associated CloudWatch alarm)

---

### RA — Risk Assessment

**RA-5 | Vulnerability Monitoring and Scanning**
- Amazon Inspector not enabled for new EC2 or container workloads
  (flag when EC2 instances or ECR repositories are added without a corresponding
  `aws_inspector2_enabler` or equivalent)
- ECR image scanning on push not enabled
  (`image_scanning_configuration { scan_on_push = false }` or absent)
- Lambda functions without `tracing_config { mode = "Active" }` when X-Ray is
  available

---

### SC — System and Communications Protection

**SC-5 | Denial of Service Protection**
- Application Load Balancers or API Gateways without an associated WAF web ACL
  (`aws_wafv2_web_acl_association` missing when public-facing ALB/API GW is added)
- CloudFront distributions without AWS Shield or WAF association for public endpoints

**SC-7 | Boundary Protection**
- VPC endpoints not used for S3, DynamoDB, or Secrets Manager when resources
  accessing these services are being added (flag absence as Medium — forces
  traffic over public internet)
- Security groups using `cidr_blocks = ["0.0.0.0/0"]` on egress rules for
  sensitive workloads
- Internet-facing ALBs in private subnets (misconfiguration)
- `associate_public_ip_address = true` on EC2 instances in private subnets

**SC-8 | Transmission Confidentiality and Integrity**
- Load balancer listeners on port 80 (HTTP) without a redirect to HTTPS
- API Gateway stages with `protocol_type = "HTTP"` rather than `HTTPS`
- Elasticsearch/OpenSearch domains with `node_to_node_encryption { enabled = false }`
- Elasticsearch/OpenSearch domains with `encrypt_at_rest { enabled = false }`
- MSK clusters without `in_cluster_encryption_in_transit { client_broker = "TLS" }`
- RDS without `storage_encrypted = true`

**SC-12 / SC-13 | Cryptographic Key Management**
- S3 buckets without server-side encryption (`server_side_encryption_configuration` absent)
- S3 buckets using SSE-S3 (AES256) rather than SSE-KMS for sensitive data
  (infer sensitivity from bucket name patterns: `phi`, `pii`, `data`, `archive`,
  `backup`, `audit`, `log`)
- EBS volumes with `encrypted = false` or absent
- RDS without `kms_key_id` specified when `storage_encrypted = true` (uses default AWS key, not CMK)
- SNS topics and SQS queues without KMS encryption
- Secrets Manager secrets without `kms_key_id` (uses default AWS key, not CMK)
- KMS keys with `key_usage = "ENCRYPT_DECRYPT"` and `is_enabled = false`
- KMS CMK policies allowing `"Principal": {"AWS": "*"}` without conditions

**SC-28 | Protection of Information at Rest**
- Any of the SC-12/SC-13 encryption-at-rest findings above also map here
- EFS file systems without `encrypted = true` and `kms_key_id`
- Glacier vaults without vault lock policies
- Kinesis streams without server-side encryption

---

### SI — System and Information Integrity

**SI-2 | Flaw Remediation**
- EC2 launch configurations/templates without SSM Agent or user-data enabling
  automatic patching
- EKS node groups using `ami_type = "AL2_x86_64"` without a patch management
  note when not using managed node groups with automatic updates
- Lambda functions using a deprecated runtime
  (flag `nodejs14.x`, `python3.7`, `python3.8`, `ruby2.7`, `java8`, `go1.x`,
  `dotnetcore3.1`, `dotnet5.0` — these are end-of-life or deprecated)

**SI-3 | Malware Protection**
- ECR repositories without image scanning on push enabled
- ECS task definitions referencing images from public registries without a
  documented approval process (images not from a private ECR registry)

**SI-4 | System Monitoring**
- CloudWatch alarms not created alongside new security-sensitive resources
  (flag when RDS, EKS, ECS, Lambda are added without corresponding CloudWatch
  metric alarms or dashboards)
- GuardDuty not enabled (flag if `aws_guardduty_detector` is absent while EC2,
  S3, or EKS resources are being added significantly)
- AWS Config rules not present (flag absence of `aws_config_configuration_recorder`
  when significant infrastructure is being added)
- Security Hub not enabled (flag absence of `aws_securityhub_account`)

**SI-7 | Software, Firmware, and Information Integrity**
- Terraform state backend without versioning enabled on the S3 bucket
- S3 buckets storing IaC state or deployment artifacts without object versioning
  (`versioning { enabled = true }` absent)
- CodePipeline or CodeBuild projects without source integrity checks

---

## Step 4 — Report

Report all findings assessed as **low severity or above**. Do not report
informational findings. Critical, high, and medium findings block the commit;
low warns without blocking.

### Report Format

```
## IaC Compliance Review Report
**Scope:** <Staged changes (git diff --cached) | Diff against <ref>>
**IaC tool(s) detected:** <Terraform / CloudFormation / Kubernetes / etc.>
**Files reviewed:** <list IaC files>
**Context files loaded:** <list, or "None">
**Controls checked:** CMS ARS 5.1 / NIST SP 800-53 Rev 5

---

### 🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM Findings (blocking)

#### [SEVERITY] [Control ID] [Control Name] — [Short title]
**File:** `path/to/file.tf`, line(s) N–M
**Resource:** `resource_type.resource_name` (if applicable)
**Finding:** Clear explanation of what was found and why it violates the control.
**CMS ARS / NIST Reference:** e.g., AC-3, SC-8, CM-6
**Remediation:** Specific, actionable IaC fix.

---

### 🔵 LOW Findings (non-blocking warnings)

#### [LOW] [Control ID] [Control Name] — [Short title]
**File:** `path/to/file.tf`, line(s) N–M
**Resource:** `resource_type.resource_name` (if applicable)
**Finding:** Clear explanation of what was found and why it is a compliance risk.
**CMS ARS / NIST Reference:** e.g., CM-2, AU-2
**Remediation:** Specific, actionable IaC fix.

---
[repeat for each finding]

---

### Summary
| Severity | Count |
|---|---|
| Critical | N |
| High | N |
| Medium | N |
| Low | N |

**Controls skipped (not applicable to this diff):** <list control IDs and reason>

**Commit recommendation:**
- 🚫 BLOCK — One or more critical, high, or medium findings. Do not commit until resolved.
- ⚠️  WARN — Low findings only. Review before committing; commit allowed.
- ✅ PASS — No findings of any severity.
```

### Severity Definitions

| Severity | Criteria | Commit impact |
|---|---|---|
| **Critical** | Public internet exposure of management ports (SSH/RDP); IAM wildcard with no conditions; unencrypted PHI/PII datastores; all S3 public access blocks disabled; publicly accessible RDS | 🚫 Blocks |
| **High** | IAM admin policies; open database ports to internet; encryption at rest disabled; CloudTrail disabled; no MFA on IAM users; hardcoded passwords; deprecated Lambda runtimes; deletion protection off on production datastores | 🚫 Blocks |
| **Medium** | Missing VPC endpoints; WAF absent on public endpoints; tagging gaps (2+ required tags missing); KMS default key instead of CMK; log retention not set; Inspector/GuardDuty absent | 🚫 Blocks |
| **Low** | Minor tagging gaps (1 tag missing); container image using `latest` tag; Lambda tracing not enabled; module without pinned version; description/name tag missing on non-critical resources | ⚠️ Warns |
| **Informational** | (Do not report) | — |

### Exit Behavior

When invoked via the pre-commit hook dispatcher, the final line of output
**must** be exactly one of:

```
<<<AI_REVIEW_RESULT:PASS>>>
<<<AI_REVIEW_RESULT:WARN>>>
<<<AI_REVIEW_RESULT:BLOCK>>>
```

- Emit `BLOCK` if any critical, high, or medium finding is present.
- Emit `WARN` if only low findings are present.
- Emit `PASS` if there are no findings at any reportable severity, or if no
  IaC files are present in the diff.

The marker must be on its own line with no surrounding text. Failure to emit
a marker causes the dispatcher to fail safe (block the commit).

---

## Notes for Reviewers

- **Scope awareness:** This review covers the diff and targeted context only.
  It is not a full Terraform plan execution or a deployed-infrastructure scan.
  Dynamic values resolved at plan/apply time (e.g., from `var.*` or `data.*`
  that are not in loaded context) cannot be fully assessed — note limitations.
- **Multi-account/environment context:** If workspace or environment cannot be
  determined, apply the stricter production-level checks and note the assumption.
- **Not a plan replacement:** This review complements but does not replace
  `terraform plan`, `cfn-lint`, `checkov`, `tfsec`, or `kube-score`. Run those
  tools in CI alongside this hook.
- **CMS ARS applicability:** ARS 5.1 applies to CMS systems and contractors.
  For non-CMS projects, the NIST 800-53 Rev 5 controls still apply; the ARS
  column simply indicates the CMS tailoring.

---

## Second-opinion adjudication

When this review reports findings (WARN or BLOCK), the dispatcher runs an
**independent adjudication pass** (`.skills/finding-adjudication/SKILL.md`): a
fresh agent re-inspects the cited resources and confirms, dismisses, or
downgrades each finding before the commit gate is decided — for example,
dismissing a "public bucket" finding when an account-level public-access block
defined in a base module already covers it. This removes false positives without
any suppression list. Report findings faithfully and cite the controlling
resource/control; the adjudicator provides the second opinion. A clean (PASS)
review is final and is never adjudicated.
