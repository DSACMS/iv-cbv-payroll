#!/usr/bin/env bash
# .skills/iac-compliance/scripts/iac-compliance-hook-dispatcher.sh
#
# Pre-commit dispatcher for the iac-compliance skill.
#
# This is a thin wrapper that defines skill-specific configuration and then
# delegates to the shared AI review dispatcher library. The library:
#   • Reads AI_REVIEW_TOOL ∈ {claude, codex, copilot}
#   • Invokes the selected CLI in non-interactive mode with the prompt below
#   • Parses <<<AI_REVIEW_RESULT:PASS|WARN|BLOCK>>> from the response
#   • Maps the result to an exit code (0 = pass/warn, 1 = block, 2 = config error)
#
# Differences from the code-security dispatcher:
#   • Uses a file filter — the review is skipped entirely when no IaC files
#     are present in the diff. This keeps non-IaC commits fast.
#   • Prompts the AI with control-family-specific instructions referencing
#     CMS ARS 5.1 / NIST SP 800-53 Rev 5.

set -euo pipefail

# ── Resolve repository root and shared library ─────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Try git first (unsetting GIT_DIR so hook env doesn't override -C resolution),
# then fall back to a relative path from this script's location.
if REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \
    git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
fi
LIB_PATH="${REPO_ROOT}/.skills/_lib/ai-review-dispatch.sh"
# Absolute path to this script — re-invoked as a single-batch worker during the
# library's parallel fan-out (see the --__review-one shim at the bottom). The
# library reads it from AI_REVIEW_SELF.
export AI_REVIEW_SELF="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"

if [[ ! -f "${LIB_PATH}" ]]; then
  echo "ERROR: shared dispatch library not found at: ${LIB_PATH}" >&2
  echo "       This file is required. Re-install the skills (see README.md)." >&2
  exit 1
fi

# ── Skill identity ──────────────────────────────────────────────────────────
SKILL_NAME="iac-compliance"
SKILL_HUMAN_NAME="IaC Compliance Review (CMS ARS 5.1 / NIST 800-53 Rev 5)"

# Canonical skill location (tool-neutral). The .claude/, .codex/, and
# .github/copilot/ directories contain derived copies populated by
# scripts/sync-skills.sh based on the developer's AI_REVIEW_TOOL setting.
SKILL_PATH_CANONICAL=".skills/iac-compliance/SKILL.md"

# ── IaC file filter ─────────────────────────────────────────────────────────
# Patterns that identify infrastructure-as-code files.
# Note: generic .yml/.yaml files are matched here too — the AI will perform
# a second-pass check inside the file (e.g., looking for `apiVersion:` and
# `kind:` to confirm Kubernetes manifests). This is intentionally broad at
# the dispatcher layer to avoid skipping K8s manifests with unusual names.
IAC_FILE_PATTERN='\.(tf|tfvars|hcl|bicep|bicepparam)$|\.tf\.json$|\.template\.(json|ya?ml)$|^(.*\/)?(Pulumi|Chart|values|kustomization)\.ya?ml$|^(.*\/)?cdk\.json$|\.ya?ml$'

# Per-file predicate: returns 0 if the given path looks like IaC. Used as the
# library's per-file batch filter so parallel fan-out only creates workers for
# IaC directories — never a wasted worker on a non-IaC batch.
iac_compliance::is_iac_file() {
  printf '%s\n' "$1" | grep -qE "${IAC_FILE_PATTERN}"
}
SKILL_BATCH_FILE_FILTER_FN="iac_compliance::is_iac_file"

# Returns 0 if at least one staged (or --against'd) file looks like IaC.
# The shared library calls this via the SKILL_FILE_FILTER_FN hook and skips
# the AI invocation entirely when this returns non-zero.
iac_compliance::has_iac_files() {
  local files
  files="$(ai_review::changed_files)"

  if [[ -z "${files}" ]]; then
    return 1
  fi

  echo "${files}" | grep -qE "${IAC_FILE_PATTERN}"
}

SKILL_FILE_FILTER_FN="iac_compliance::has_iac_files"

# ── Prompt construction ─────────────────────────────────────────────────────
read -r -d '' SKILL_PROMPT <<'PROMPT' || true
You have access to the iac-compliance skill. The skill's full instructions
are in this repository at:

  .skills/iac-compliance/SKILL.md

(Tool-specific copies may also exist at .claude/skills/iac-compliance/SKILL.md,
.codex/skills/iac-compliance/SKILL.md, or .github/copilot/skills/iac-compliance/SKILL.md;
all are byte-identical to the canonical file above.)

Read the SKILL.md, then run a full IaC compliance review on the diff
identified by the environment (default: staged changes from
`git diff --cached`; if the dispatcher's --against flag was used, the
AI_REVIEW_AGAINST environment variable will be set, and the diff range is
available via `git diff $AI_REVIEW_AGAINST HEAD`).

If the AI_REVIEW_SCOPE_PATHS environment variable is set (newline-separated
paths), you are one worker in a parallel review — restrict this review to EXACTLY
those paths. Collect the diff with `git diff --cached -- $AI_REVIEW_SCOPE_PATHS`
(or `git diff $AI_REVIEW_AGAINST HEAD -- $AI_REVIEW_SCOPE_PATHS` when
AI_REVIEW_AGAINST is set) and do not report findings outside that set. You see
only a slice of the commit: if confirming a finding would require a file outside
your scope, still report it and note that cross-file confirmation is needed.

Follow the skill instructions exactly:
  1. Collect the diff using the appropriate git command.
  2. Detect the IaC tool(s) in use (Terraform, CloudFormation, Bicep, Pulumi,
     Ansible, Kubernetes, Helm, CDK, etc.).
  3. Load targeted context files as described in the skill, up to the ceiling in
     the AI_REVIEW_CONTEXT_BUDGET environment variable (default 15 when unset; a
     smaller value is set when reviewing a small batch).
  4. Run the control-family checks (AC, AU, CM, CP, IA, RA, SC, SI) that are
     applicable to the changed code. Cite each finding with its NIST 800-53 /
     CMS ARS 5.1 control ID.
  5. Report all findings of low severity or above using the report format in
     the skill, with the severity-to-result mapping:
        Critical, High, Medium  → contributes to BLOCK
        Low                     → contributes to WARN
        (No findings)           → PASS

If no IaC files are present in the diff, emit PASS — but the dispatcher will
have already short-circuited this case, so you should not normally see it.

After your full report, end your response with EXACTLY ONE of the following
markers, on its own line, with no surrounding text. The dispatcher script
parses this marker to decide whether to allow the commit. Failure to emit a
marker will cause the commit to be blocked as a safety measure.

  <<<AI_REVIEW_RESULT:PASS>>>
  <<<AI_REVIEW_RESULT:WARN>>>
  <<<AI_REVIEW_RESULT:BLOCK>>>

Emit BLOCK if any critical, high, or medium finding is present.
Emit WARN if only low findings are present.
Emit PASS if there are no findings at any reportable severity.
PROMPT

# ── Delegate to shared library ──────────────────────────────────────────────
# shellcheck source=../../_lib/ai-review-dispatch.sh
source "${LIB_PATH}"

# Append the shared single-pass self-adjudication step. The model applies it only
# when AI_REVIEW_ADJUDICATION_MODE=self (the default); the library exports the
# resolved mode before invoking, so independent/off first passes report raw.
SKILL_PROMPT="${SKILL_PROMPT}

$(ai_review::self_adjudication_instructions)"

# Worker mode: the library's parallel fan-out re-invokes this dispatcher as
# `--__review-one <record>` (one batch per worker). The re-run rebuilds the same
# SKILL_PROMPT above, so the worker reviews with this skill's instructions.
if [[ "${1:-}" == "--__review-one" ]]; then
  ai_review::worker_main "${2:-}"
else
  ai_review::run "$@"
fi
