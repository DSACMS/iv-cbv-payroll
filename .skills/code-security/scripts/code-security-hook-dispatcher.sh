#!/usr/bin/env bash
# .skills/code-security/scripts/code-security-hook-dispatcher.sh
#
# Pre-commit dispatcher for the code-security skill.
#
# This is a thin wrapper that defines skill-specific configuration and then
# delegates to the shared AI review dispatcher library. The library:
#   • Reads AI_REVIEW_TOOL ∈ {claude, codex, copilot}
#   • Invokes the selected CLI in non-interactive mode with the prompt below
#   • Parses <<<AI_REVIEW_RESULT:PASS|WARN|BLOCK>>> from the response
#   • Maps the result to an exit code (0 = pass/warn, 1 = block, 2 = config error)
#
# This script is invoked by pre-commit via the local hook entry in
# .pre-commit-config.yaml, and may also be run manually:
#
#     ./code-security-hook-dispatcher.sh                # default: staged diff
#     ./code-security-hook-dispatcher.sh --dry-run      # show plan, don't call AI
#     ./code-security-hook-dispatcher.sh --no-block     # run, never block
#     ./code-security-hook-dispatcher.sh --against HEAD~1   # ad-hoc review

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
SKILL_NAME="code-security"
SKILL_HUMAN_NAME="Code Security Review"

# Canonical skill location (tool-neutral). The .claude/, .codex/, and
# .github/copilot/ directories contain derived copies populated by
# scripts/sync-skills.sh based on the developer's AI_REVIEW_TOOL setting.
SKILL_PATH_CANONICAL=".skills/code-security/SKILL.md"

# ── Prompt construction ─────────────────────────────────────────────────────
# The prompt references the canonical SKILL.md path so the AI loads its full
# instructions regardless of which CLI is invoked. All three derived copies
# are byte-identical to this canonical file; pointing at the canonical avoids
# tool-specific branching in the prompt.

read -r -d '' SKILL_PROMPT <<'PROMPT' || true
You have access to the code-security skill. The skill's full instructions
are in this repository at:

  .skills/code-security/SKILL.md

(Tool-specific copies may also exist at .claude/skills/code-security/SKILL.md,
.codex/skills/code-security/SKILL.md, or .github/copilot/skills/code-security/SKILL.md;
all are byte-identical to the canonical file above.)

Read the SKILL.md, then run a full security review on the diff identified by
the environment (default: staged changes from `git diff --cached`; if a
non-default diff range was passed via the dispatcher's --against flag, the
AI_REVIEW_AGAINST environment variable will be set to that ref — in that case,
review the diff returned by `git diff $AI_REVIEW_AGAINST HEAD`).

If the AI_REVIEW_SCOPE_PATHS environment variable is set (newline-separated
paths), you are one worker in a parallel review — restrict this review to EXACTLY
those paths. Collect the diff with `git diff --cached -- $AI_REVIEW_SCOPE_PATHS`
(or `git diff $AI_REVIEW_AGAINST HEAD -- $AI_REVIEW_SCOPE_PATHS` when
AI_REVIEW_AGAINST is set) and do not report findings outside that set. You see
only a slice of the commit: if confirming a finding would require a file outside
your scope, still report it and note that cross-file confirmation is needed.

Follow the skill instructions exactly:
  1. Collect the diff using the appropriate git command.
  2. Identify and load targeted context files as described in the skill, up to
     the ceiling in the AI_REVIEW_CONTEXT_BUDGET environment variable (default
     15 when unset; a smaller value is set when reviewing a small batch).
  3. Run mandatory secrets / PII / PHI detection.
  4. Apply the OWASP Top 10 checks where relevant to the diff.
  5. Run the general security review section.
  6. Report all findings of low severity or above using the report format in
     the skill, with the severity-to-result mapping:
        Critical, High, Medium  → contributes to BLOCK
        Low                     → contributes to WARN
        (No findings)           → PASS

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
