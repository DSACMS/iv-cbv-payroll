---
name: finding-adjudication
description: >
  Independent second-opinion adjudication of an automated first-pass security or
  compliance review. Given a first-pass findings report, re-inspect the cited
  code with fresh eyes and classify each finding as confirmed, false positive, or
  overstated (downgraded), with a one-line rationale each. Removes false positives
  before they reach the developer or report, without any manual suppression list.
  Invoked automatically by the dispatcher when a first pass reports findings; the
  gate is then decided by the adjudicated result.
---

# Finding Adjudication Skill

A focused **second-opinion** review. The pre-commit and codebase-audit phases run
a first-pass review (`code-security`, `iac-compliance`, or `codebase-audit`). When
that first pass reports findings, this skill runs as an **independent adjudicator**:
a fresh agent, with no memory of the first pass, that re-examines the actual code
and decides which findings are real.

The goal is to **cut false positives** — synthetic test data flagged as a real
secret, a mitigated pattern flagged as exploitable, a control assumed missing that
is actually present elsewhere — so developers and auditors see a clean, trustworthy
report. It does this with **no suppression file and no manual bookkeeping**: every
run re-derives the truth from the code.

This skill is invoked by the shared dispatcher (`.skills/_lib/ai-review-dispatch.sh`,
`ai_review::adjudicate`) which selects an AI assistant via `AI_REVIEW_TOOL`
(`claude` | `codex` | `copilot`) and, optionally, a distinct `AI_ADJUDICATION_MODEL`
for a more independent second opinion. The instructions are identical across all
three assistants.

This file (`.skills/finding-adjudication/SKILL.md`) is the **canonical** copy;
byte-identical derived copies may exist under `.claude/`, `.codex/`, or
`.github/copilot/` per `scripts/sync-skills.sh`.

---

## Operating principle: skeptical, but security-first

You are adversarial toward the **first pass**, not toward the code. Assume the
first pass may have over-flagged — but **never** trade away a real risk to produce
a tidy report.

> **When you cannot verify a finding is false, keep it.** Dismissal requires
> positive evidence that the finding is wrong. Absence of evidence is not grounds
> to dismiss. Ties go to security.

You may only make findings **less** severe (confirm as-is, downgrade, or dismiss).
You must **not** invent new findings or raise severities — that is the first pass's
job, and escalation here would make the gate non-deterministic.

---

## Inputs (provided by the dispatcher)

- **The first-pass report**, embedded in the prompt below a `FIRST-PASS REPORT`
  banner. Each finding carries a severity, a category/control, a `file:line`, and a
  rationale.
- **The marker vocabulary** to emit (`PASS/WARN/BLOCK` for pre-commit, or
  `CLEAN/FINDINGS` for audit) — stated in the prompt.
- **The code under review.** For diff-mode reviews, the staged diff
  (`git diff --cached`) or, if `AI_REVIEW_AGAINST` is set, `git diff $AI_REVIEW_AGAINST HEAD`.
  For audit-mode reviews, the files cited in the report. **Read the actual code
  yourself** — do not adjudicate from the report's prose alone.

---

## Step 1 — Re-inspect each finding against the real code

For every finding in the first-pass report:

1. Open the cited `file:line` and read enough surrounding context to judge it.
2. Verify the claim independently. Does the evidence actually support the finding
   at the stated severity?
3. Classify it (Step 2).

---

## Step 2 — Classify

Assign exactly one verdict per finding:

| Verdict | Meaning | Effect |
|---|---|---|
| **CONFIRMED** | The finding is real at its stated severity. | Kept as-is. |
| **OVERSTATED** | Real, but the severity is too high given the evidence/context. | Kept at a corrected **lower** severity. |
| **FALSE_POSITIVE** | Not a genuine issue. | Removed from the gate; recorded with its reason. |

### Legitimate grounds to dismiss or downgrade (must be verified, not assumed)
- **Synthetic / placeholder data** — `example.com`, `test@example.com`, `555-0100`,
  `000-00-0000`, `AKIAIOSFODNN7EXAMPLE` and other well-known doc/sample values,
  obviously fake names/IDs in fixtures or documentation. (Confirm it is truly
  synthetic — placeholder-looking strings are occasionally real.)
- **Already mitigated** — the flagged pattern has an effective control in the same
  or an imported path (parameterized query, sanitizer, authz check, encryption at a
  layer the first pass didn't load).
- **Out-of-context assumption** — the first pass assumed something absent that is
  actually present elsewhere (a control defined in a base module, a default applied
  by the framework).
- **Misclassification** — e.g., a value matched a secret regex but is a public
  identifier, constant, or hash with no secret value.

### NOT legitimate grounds to dismiss
- "It's probably fine" / "looks like test code" without opening the file.
- "It's only in a test/fixture" when the value could still be a real credential.
- Style or convenience preferences. Dismissal is about correctness, not taste.
- Any plausible real secret, real PII/PHI, or exploitable vulnerability that you
  cannot positively show to be benign → **CONFIRMED**.

---

## Step 3 — Produce the revised report

Reproduce the **same structure and summary-table format** as the first-pass report
(so downstream tooling that parses the severity table keeps working), with two
changes:

1. The findings list contains only **CONFIRMED** and **OVERSTATED** findings, each
   at its **final** severity. Recompute the summary table counts accordingly.
2. Append a section that records every change, so nothing is hidden:

```
### Dismissed / Downgraded by adjudication

- [FALSE_POSITIVE] `path/to/file.py:14` — [orig: HIGH] secrets —
  Reason: value is the AWS-documented example key `AKIA...EXAMPLE`, not a live credential.
- [DOWNGRADED HIGH→LOW] `path/to/file.tf:22` — Reason: bucket is private via the
  account-level public-access block defined in `modules/baseline/main.tf`.
```

If the first-pass report contained a SARIF block (delimited by
`<!-- AUDIT_SARIF_BEGIN -->` / `<!-- AUDIT_SARIF_END -->`), emit an updated block
between the same delimiters containing only the confirmed findings at their final
severities.

---

## Step 4 — Emit the result marker

Compute the marker from the **confirmed findings only** (after dismissals and
downgrades), using the vocabulary the dispatcher specified, on its own final line:

**Pre-commit** (`code-security`, `iac-compliance`):
```
<<<AI_REVIEW_RESULT:PASS>>>    no confirmed findings remain at any severity
<<<AI_REVIEW_RESULT:WARN>>>    only confirmed Low findings remain
<<<AI_REVIEW_RESULT:BLOCK>>>   one or more confirmed Critical/High/Medium remain
```

**Audit** (`codebase-audit`):
```
<<<AI_REVIEW_RESULT:CLEAN>>>      no confirmed findings remain at or above threshold
<<<AI_REVIEW_RESULT:FINDINGS>>>   one or more confirmed findings remain
```

Emit exactly one marker, on its own line, with no surrounding text. If you emit no
marker, the dispatcher keeps the stricter first-pass result (fail-safe).
