---
name: codebase-audit
description: >
  Perform a comprehensive security and IaC-compliance audit of an entire
  existing codebase, directory-by-directory. Unlike the pre-commit and PR
  review skills which review diffs, this skill reviews the full content of
  files at rest. Designed for one-time baseline audits, periodic full
  reviews (e.g., quarterly), audits before a compliance assessment, and
  audits of repositories being onboarded into a regulated environment.
  Produces one markdown report per directory batch in audit-reports/,
  optionally with SARIF output for ingestion into security dashboards.
  Supports min-severity filtering and resume mode for long-running audits.
---

# Codebase Audit Skill

This skill is fundamentally different from `code-security`, `iac-compliance`,
and `pr-review`. Those skills review **changes**. This skill reviews
**state** — the full content of every reviewable file in the repository,
batched by directory, producing a per-directory finding report.

> **When to use this skill:** baseline audits when onboarding a new
> codebase, periodic full reviews (quarterly is common for FedRAMP /
> FISMA / HIPAA-bound systems), pre-assessment audits before an external
> compliance review, or one-time deep-dives on suspect subsystems.
>
> **When NOT to use this skill:** routine development. Use the pre-commit
> and PR-review skills for that — they are tuned for diffs and run in
> seconds, while this skill scans the full repo and can run for an hour
> or more. (The dispatcher audits multiple directories concurrently — see
> its `--jobs` / `AUDIT_JOBS` option — which shortens that wall-clock time
> substantially without changing the reports.)

This file (`.skills/codebase-audit/SKILL.md`) is the **canonical** copy.
Each developer's chosen AI tool reads either this file or a byte-identical
derived copy under `.claude/`, `.codex/`, or `.github/copilot/`, depending
on what `scripts/sync-skills.sh` produced for their `AI_REVIEW_TOOL`
setting.

---

## Execution Overview

The dispatcher (`.skills/codebase-audit/scripts/codebase-audit-dispatcher.sh`)
controls the audit loop. The AI does not pick which directories to audit;
the dispatcher does that and invokes the AI once per batch with a fresh
context. Batches are independent, so the dispatcher can audit several at
once (`--jobs N`, default 4); planning stays deterministic and only
execution fans out. This matters because:

1. **Determinism** — the same dispatcher run on the same codebase produces
   the same batching plan, which makes reports comparable across runs.
2. **Resume safety** — the dispatcher can skip batches whose reports
   already exist, so a 45-minute audit interrupted at the 30-minute mark
   can resume without redoing work.
3. **Cost control** — each AI invocation has a bounded scope (one
   directory), so cost scales linearly with the number of directories,
   not exponentially.

The high-level loop:

```
dispatcher:
  1. Enumerate candidate directories (filter out skip list)
  2. For each directory:
     a. If audit-reports/<dir>.md already exists and --force not set, skip
     b. Otherwise, invoke AI with this skill + the directory scope
     c. AI produces a per-directory report
     d. dispatcher writes audit-reports/<dir>.md
  3. After all directories: produce audit-reports/_INDEX.md — a
     findings-first triage view that lists directories with findings
     worst-first and collapses the clean ones out of the way
  4. Optionally also emit audit-reports/_findings.sarif
```

When the AI is invoked, it receives:

- The skill instructions in this file
- The directory in scope (`AUDIT_SCOPE_DIR` env var)
- The list of files in scope (from `git ls-files` filtered by skip rules)
- A pointer to the security perspective (`.skills/code-security/SKILL.md`)
- A pointer to the compliance perspective (`.skills/iac-compliance/SKILL.md`)
- A min-severity threshold (`AUDIT_MIN_SEVERITY`, default: low)

The AI's job: read every file in the directory, apply both perspectives,
produce a structured report.

---

## Step 1 — Receive the Audit Scope

The dispatcher passes the scope via environment variables:

| Variable | Meaning | Example |
|---|---|---|
| `AUDIT_SCOPE_DIR` | Repo-relative directory currently being audited | `src/api/auth` |
| `AUDIT_SCOPE_FILES` | Newline-separated list of files in scope | `src/api/auth/login.py\nsrc/api/auth/jwt.py` |
| `AUDIT_MIN_SEVERITY` | Lowest severity to report | `medium` |
| `AUDIT_REPO_ROOT` | Absolute path to the repo root | `/home/dev/myrepo` |

Read every file listed in `AUDIT_SCOPE_FILES`. Do not range outside the
scope directory unless loading context (see Step 2).

---

## Step 2 — Load Targeted Context

Audit-mode context loading is different from diff-mode. Diff-mode context
is "what do I need to understand this change?" Audit-mode context is
"what do I need to understand this directory's role in the larger
system?"

Apply these rules, with a hard ceiling of **20 additional context files
per audit batch**:

| Context type | When to load | Ceiling |
|---|---|---|
| **Direct importers** | Files outside the scope dir that `import` / `require` / `use` / `source` files inside the scope dir. Helps determine whether internal-only assumptions hold. | 10 |
| **Project config** | `tsconfig.json`, `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, top-level `README.md`. Helps anchor language, frameworks, and stated security posture. | 5 |
| **IaC parents** | When auditing an IaC module, the calling module / root config that instantiates it. Helps assess whether weak defaults are overridden upstream. | 5 |

Do **NOT** load:

- Lock files (`package-lock.json`, `poetry.lock`, `Cargo.lock`, etc.)
- Build artifacts, generated code, vendored dependencies
- `node_modules/`, `.venv/`, `vendor/`, `target/`, `dist/`, `build/`,
  `__pycache__/`, `.next/`, `.nuxt/`, `coverage/`
- The full source tree by walking parents — limit to direct importers only
- Test fixtures unless they directly inform a finding (e.g., a hardcoded
  secret in test code that's actually production-shaped)

If you would exceed the ceiling, prioritize **direct importers of
security-sensitive files** (auth code, IaC, anything in the scope dir
that handles credentials, PII, or PHI) and note in the report that
context was truncated.

---

## Step 3 — Apply Both Perspectives

The audit applies the same two perspectives as the PR-review skill,
against full file content rather than a diff:

### Security perspective

Read `.skills/code-security/SKILL.md` for the full check list. Apply
every check to every file in scope. The relevant categories:

- Hardcoded secrets, credentials, tokens, API keys
- PII / PHI exposure (logging, error messages, response payloads)
- OWASP Top 10 (A01–A10:2021)
- Specific known dangerous patterns (eval, deserialize, SSRF, XXE, etc.)

### Compliance perspective

Read `.skills/iac-compliance/SKILL.md` for the full check list. Apply
every check to every IaC file in scope. The relevant control families:

- AC — Access Control
- AU — Audit and Accountability
- CM — Configuration Management
- CP — Contingency Planning
- IA — Identification and Authentication
- RA — Risk Assessment
- SC — System and Communications Protection
- SI — System and Information Integrity

Compliance findings must cite NIST SP 800-53 Rev 5 control IDs and (where
they differ in tailoring) CMS ARS 5.1 control IDs.

---

## Step 4 — Apply Severity Filter

The dispatcher passes `AUDIT_MIN_SEVERITY` (one of `critical`, `high`,
`medium`, `low`). Use the same severity ladder as the other skills:

| Severity | Examples |
|---|---|
| **CRITICAL** | Hardcoded secrets/credentials; real PHI; RCE; auth bypass; SSH/RDP open to `0.0.0.0/0`; IAM wildcard with no conditions |
| **HIGH** | Real PII; SQL/command injection; broken access control; encryption at rest disabled; CloudTrail off; deprecated crypto |
| **MEDIUM** | Injection with partial mitigation; missing WAF on public endpoint; 2+ required tags missing; KMS default key |
| **LOW** | Minor hygiene; 1 required tag missing; image tagged `latest`; missing X-Ray |

Findings **at or above** the threshold are reported. Findings below are
omitted entirely — not summarized, not counted, not mentioned. If
`AUDIT_MIN_SEVERITY=high`, the report must contain zero Medium and zero
Low findings.

This is intentional. Audits often produce hundreds of Low findings that
are real but not actionable in a 90-day window. Filtering to High+
focuses human review on what can be triaged immediately.

---

## Step 5 — Emit the Per-Directory Report

Write the report to **stdout** (the dispatcher captures it and writes
the file). Use this exact structure:

````markdown
# Audit Report: `<AUDIT_SCOPE_DIR>`

**Files in scope:** N
**Context files loaded:** M (importers: X, config: Y, parents: Z)
**Severity threshold:** <CRITICAL|HIGH|MEDIUM|LOW>
**Perspectives applied:** Security; Compliance (or: Security only — no IaC files)

## Summary

| Severity | Security | Compliance | Total |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High     | 0 | 0 | 0 |
| Medium   | 0 | 0 | 0 |
| Low      | 0 | 0 | 0 |
| **Total** | | | **0** |

## Findings

### 🔴 CRITICAL

#### `src/api/auth/jwt.py:14` — `security` — Hardcoded JWT signing secret

The `JWT_SECRET` constant is set to a literal string rather than read from
an environment variable or secrets manager. Any process with access to
source can mint valid tokens. OWASP A02:2021 – Cryptographic Failures.

**Recommended fix:**
```python
JWT_SECRET = os.environ["JWT_SECRET"]
```

Rotate the existing secret immediately — assume it is compromised.

---

### 🟠 HIGH

#### `infra/rds.tf:12` — `compliance` — RDS instance without encryption at rest

The `aws_db_instance` resource omits `storage_encrypted`, leaving the
instance with encryption disabled. NIST SC-12 / SC-28, CMS ARS SC-28(HIGH).

**Recommended fix:**
```hcl
resource "aws_db_instance" "main" {
  # ... existing config ...
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
}
```

---

### 🟡 MEDIUM

(no findings at this severity)

### 🔵 LOW

(no findings at this severity)

## Files reviewed

- `src/api/auth/jwt.py`
- `src/api/auth/login.py`
- `src/api/auth/middleware.py`

## Context files loaded

- `src/api/server.py` (importer)
- `pyproject.toml` (project config)

## Notes from the reviewer

(Optional free-text section. Use for caveats — e.g., "two files were
unreadable due to non-UTF-8 encoding and were skipped" or "the auth
middleware has no apparent caller in the scope dir; verify it's wired
in upstream.")
````

### Reporting rules

- **Group by severity descending.** Critical first, then High, Medium,
  Low. Within a severity, group by perspective (security first, then
  compliance). Within a perspective, order by file path alphabetically.
- **One finding per issue.** If the same vulnerability appears on five
  lines (e.g., five resources missing the same tag), emit one finding
  per resource — not five for one root cause across one resource, and
  not one overarching one for all five resources.
- **File:line precision required.** Every finding must have a
  `<file>:<line>` heading. If the issue spans multiple lines, use the
  line of the most relevant token (e.g., the `resource "..." "..." {`
  line for an IaC resource, the `def function_name(...)` line for a
  Python function).
- **Recommended fix is mandatory** when the fix is concrete (a code or
  config change). Use a fenced code block in the appropriate language.
  Mark structural fixes (e.g., "add a new resource elsewhere") with
  prose rather than an in-line code block.
- **Cite controls and categories.** Security findings cite OWASP where
  applicable. Compliance findings cite NIST 800-53 Rev 5 control IDs and
  CMS ARS 5.1 control IDs.
- **Redact secrets in findings.** Never include the actual value of a
  secret in the report. Use `AKIA...XXXX` or similar.

---

## Step 6 — Emit a Result Marker

End the response with exactly one of:

```
<<<AI_REVIEW_RESULT:CLEAN>>>            (no findings at or above threshold)
<<<AI_REVIEW_RESULT:FINDINGS>>>         (one or more findings at or above threshold)
```

These markers differ from the diff-mode skills (PASS/WARN/BLOCK) and the
PR-review skill (APPROVE/COMMENT/REQUEST_CHANGES) because audit semantics
are different — there's nothing to gate, only state to report.

The marker must be on its own line with no surrounding text.

---

## Step 7 — Optional: SARIF Output

If the dispatcher passes `AUDIT_EMIT_SARIF=1`, also emit a SARIF 2.1.0
JSON object between these markers (after the report, before the result
marker):

```
<!-- AUDIT_SARIF_BEGIN -->
{ ...SARIF 2.1.0 object... }
<!-- AUDIT_SARIF_END -->
```

The dispatcher merges per-batch SARIF blocks into a single
`audit-reports/_findings.sarif` for ingestion into security tooling
(GitHub code scanning, DefectDojo, Snyk, etc.). Use rule IDs of the
form:

- `security/<owasp-category-or-pattern>` — e.g., `security/A02-crypto-failure`
- `compliance/<nist-control-id>` — e.g., `compliance/SC-28`

SARIF emission is opt-in because it doubles the AI output size; only set
the env var when the SARIF file is actually wanted.

---

## Notes for the auditor

- **The audit is large and slow by design.** A 100-directory codebase
  produces 100 reports. That's the right shape — humans triage one
  directory's findings at a time. Resist the temptation to bundle.
- **Severity is your responsibility.** When in doubt, choose the lower
  severity and note the uncertainty in the finding's body.
- **No noise findings.** This skill is for findings that warrant human
  triage. Naming, formatting, comment quality, and other code-style
  concerns are out of scope. If a finding wouldn't make it into a
  pentest report, omit it.
- **No duplicate cross-batch findings.** Each audit batch is scoped to
  one directory. Do not flag a Cloud-wide issue (e.g., "this org has no
  S3 access logging at the account level") in every batch — flag it
  once, in the most relevant batch (e.g., `infra/` root or `iam/`).
- **Honor the severity filter strictly.** If the threshold is `high`,
  the report must contain zero Medium and zero Low entries — not even
  in a "noted but not reported" section.

---

## Second-opinion adjudication

When a directory's audit returns `FINDINGS`, the dispatcher runs an
**independent adjudication pass** (`.skills/finding-adjudication/SKILL.md`)
before writing that directory's report: a fresh agent re-inspects the cited code
and confirms, dismisses, or downgrades each finding, so the per-directory report,
the `_INDEX.md` counts, and the SARIF all reflect the adjudicated result. The
revised report keeps this skill's exact structure (summary table + findings
sections) and appends a "Dismissed / Downgraded by adjudication" section. A
`CLEAN` directory is final and is never adjudicated. Produce your findings
faithfully at the right severity per the rules above; the adjudicator provides
the independent second opinion (disable it with `--no-adjudicate` if needed).
