#!/usr/bin/env bash
# .skills/_lib/ai-review-dispatch.sh
#
# Shared dispatch library sourced by skill hook dispatcher scripts.
#
# This library is tool-agnostic. It resolves which AI coding assistant to call
# (claude | codex | copilot) based on the AI_REVIEW_TOOL environment variable,
# invokes the chosen CLI in non-interactive mode with a deterministic prompt,
# and parses a structured result marker out of the response.
#
# Sourcing scripts must define the following variables BEFORE sourcing this
# library, then call ai_review::run.
#
#   SKILL_NAME              — short id, e.g. "code-security"
#   SKILL_HUMAN_NAME        — display name, e.g. "Code Security Review"
#   SKILL_PROMPT            — full prompt text passed to the AI CLI
#   SKILL_PATH_CANONICAL    — path to canonical SKILL.md under .skills/
#
# Optional:
#   SKILL_FILE_FILTER_FN  — name of a function that returns 0 if at least one
#                           relevant file is staged, 1 otherwise. If unset, the
#                           dispatcher runs regardless of file types.
#
# Result marker contract:
#   The AI is instructed to end its output with EXACTLY ONE of:
#       <<<AI_REVIEW_RESULT:PASS>>>
#       <<<AI_REVIEW_RESULT:WARN>>>
#       <<<AI_REVIEW_RESULT:BLOCK>>>
#
# Severity policy (uniform across all skills):
#   Critical, High, Medium  → BLOCK (exit 1)
#   Low                     → WARN  (exit 0, with warning banner)
#   None                    → PASS  (exit 0)
#
# Exit codes:
#   0  — PASS or WARN (commit may proceed)
#   1  — BLOCK or unrecoverable error (commit must be rejected)
#   2  — Configuration error (AI_REVIEW_TOOL unset or invalid)
#
# Adjudication (false-positive reduction), via AI_ADJUDICATION:
#   self        (DEFAULT) Single-pass self-adjudication — the review prompt tells
#               the model to re-examine its own candidate findings as a skeptic
#               and report only confirmed ones, in ONE call. Fast and cheap.
#   independent An additional fresh-agent second pass re-inspects a BLOCK result
#               (scoped to the finding-bearing files; honors AI_ADJUDICATION_MODEL
#               so the second opinion can run on a different model of the same
#               CLI). Strongest, but ~doubles time/cost on finding-bearing reviews.
#               If the pass fails or returns no marker, the first-pass result
#               stands (fail-safe).
#   off         No adjudication (raw first-pass findings; --no-adjudicate forces this).
#   Skipping adjudication never lowers detection (it can only confirm / dismiss /
#   downgrade), so "off" is the stricter (block-more) direction. The default is
#   "self" for both pre-commit and codebase-audit.

set -euo pipefail

# ── Library guard ───────────────────────────────────────────────────────────
if [[ "${_AI_REVIEW_DISPATCH_LOADED:-0}" == "1" ]]; then
  return 0
fi
_AI_REVIEW_DISPATCH_LOADED=1

# ── Color helpers (suppressed in CI / non-TTY) ──────────────────────────────
if [[ -t 1 ]] && [[ "${CI:-}" != "true" ]] && [[ "${NO_COLOR:-}" == "" ]]; then
  AI_C_RED=$'\033[0;31m'
  AI_C_YELLOW=$'\033[1;33m'
  AI_C_GREEN=$'\033[0;32m'
  AI_C_BLUE=$'\033[0;34m'
  AI_C_BOLD=$'\033[1m'
  AI_C_RESET=$'\033[0m'
else
  AI_C_RED=""
  AI_C_YELLOW=""
  AI_C_GREEN=""
  AI_C_BLUE=""
  AI_C_BOLD=""
  AI_C_RESET=""
fi

# ── Logging helpers ─────────────────────────────────────────────────────────
ai_review::log()  { printf '%s\n' "$*"; }
ai_review::info() { printf '%s[%s]%s %s\n' "${AI_C_BOLD}" "${SKILL_NAME}" "${AI_C_RESET}" "$*"; }
ai_review::ok()   { printf '%s[%s] %s%s\n' "${AI_C_GREEN}" "${SKILL_NAME}" "$*" "${AI_C_RESET}"; }
ai_review::warn() { printf '%s[%s] %s%s\n' "${AI_C_YELLOW}" "${SKILL_NAME}" "$*" "${AI_C_RESET}" >&2; }
ai_review::err()  { printf '%s[%s] ERROR: %s%s\n' "${AI_C_RED}" "${SKILL_NAME}" "$*" "${AI_C_RESET}" >&2; }

# ── CLI flag parsing ────────────────────────────────────────────────────────
# Sets:
#   AI_REVIEW_DRY_RUN      ("1" or "0") — print what would happen, do not call AI
#   AI_REVIEW_NO_BLOCK     ("1" or "0") — run review but never exit non-zero
#   AI_REVIEW_AGAINST      (string)     — git ref to diff against; default = staged
#   AI_REVIEW_JOBS         (int)        — concurrent workers (1 = serial; default 4)
#   AI_REVIEW_LIST_BATCHES ("1" or "0") — print the batch plan and exit
#   AI_REVIEW_REMAINING    (array)      — any unparsed args
ai_review::parse_args() {
  AI_REVIEW_DRY_RUN=0
  AI_REVIEW_NO_BLOCK=0
  AI_REVIEW_NO_ADJUDICATE=0
  AI_REVIEW_AGAINST=""
  AI_REVIEW_LIST_BATCHES=0
  # Concurrency: env default (validated below), overridable by --jobs.
  AI_REVIEW_JOBS="${AI_REVIEW_JOBS:-4}"
  AI_REVIEW_REMAINING=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        AI_REVIEW_DRY_RUN=1
        shift
        ;;
      --no-block)
        AI_REVIEW_NO_BLOCK=1
        shift
        ;;
      --no-adjudicate)
        AI_REVIEW_NO_ADJUDICATE=1
        shift
        ;;
      --against)
        if [[ -z "${2:-}" ]]; then
          ai_review::err "--against requires a git ref argument"
          exit 2
        fi
        AI_REVIEW_AGAINST="$2"
        shift 2
        ;;
      --against=*)
        AI_REVIEW_AGAINST="${1#*=}"
        shift
        ;;
      --jobs)
        AI_REVIEW_JOBS="${2:-}"
        shift 2
        ;;
      --jobs=*)
        AI_REVIEW_JOBS="${1#*=}"
        shift
        ;;
      --list-batches)
        AI_REVIEW_LIST_BATCHES=1
        shift
        ;;
      -h|--help)
        ai_review::print_help
        exit 0
        ;;
      --)
        shift
        AI_REVIEW_REMAINING+=("$@")
        break
        ;;
      *)
        AI_REVIEW_REMAINING+=("$1")
        shift
        ;;
    esac
  done

  # Validate JOBS now that flag/env are resolved.
  if ! [[ "${AI_REVIEW_JOBS}" =~ ^[0-9]+$ ]] || (( AI_REVIEW_JOBS < 1 )); then
    ai_review::err "--jobs / AI_REVIEW_JOBS must be a positive integer (got '${AI_REVIEW_JOBS}')."
    exit 2
  fi
}

ai_review::print_help() {
  cat <<EOF
${SKILL_HUMAN_NAME} — pre-commit dispatcher

Usage:
  $(basename "${BASH_SOURCE[1]:-$0}") [options]

Options:
  -n, --dry-run        Print the resolved AI tool, prompt, and target files,
                       but do not invoke the AI. Exits 0.
  --no-block           Run the full review but always exit 0, regardless of
                       findings (useful for testing in CI without blocking).
  --no-adjudicate      Disable adjudication entirely (no self-critique, no
                       second pass) — raw first-pass findings. Same as
                       AI_ADJUDICATION=off.
  --against <ref>      Review the diff between <ref> and HEAD (or working tree)
                       instead of the staged changes. Useful for ad-hoc review,
                       e.g.  --against HEAD~1   or  --against main
  --jobs <N>           Run up to N batches concurrently when the diff is large
                       enough to fan out (default 4; also AI_REVIEW_JOBS).
                       1 = serial. The ceiling is the AI vendor's rate limit.
  --list-batches       Print how the diff would be split into batches (and
                       whether it would fan out) without invoking the AI. Exits 0.
  -h, --help           Show this help and exit.

Environment variables:
  AI_REVIEW_TOOL         Required. One of: claude | codex | copilot.
  AI_ADJUDICATION        False-positive reduction mode (default "self"):
                           self        single-pass self-adjudication — the review
                                       re-examines its own findings and reports
                                       only confirmed ones, in ONE call (fast,
                                       cheap; the default for pre-commit & audit).
                           independent an extra fresh-agent second pass on a BLOCK
                                       result (scoped to the finding-bearing
                                       files; honors AI_ADJUDICATION_MODEL).
                                       Strongest, ~doubles time/cost on findings.
                           off         no adjudication (raw first-pass findings).
                         (Back-compat: "1" maps to independent, "0" to off.)
  AI_ADJUDICATION_MODEL  Optional. Model name passed to the same AI_REVIEW_TOOL
                         CLI for the independent adjudication pass only (a
                         different model for the second opinion). Has no effect in
                         "self" mode. If unset, the tool's default model is used.
  AI_REVIEW_JOBS         Concurrent workers for the parallel fan-out (default 4;
                         overridden by --jobs). 1 = serial.
  AI_REVIEW_BATCH_BY     "dir" (default) groups changed files by directory — one
                         worker per directory, preserving cross-file context
                         within it. "file" runs one worker per changed file
                         (maximum concurrency, higher total token cost, and it
                         cannot see cross-file context).
  AI_REVIEW_BATCH_MIN_FILES
                         Minimum changed files before the diff is fanned out
                         (default 10). Smaller commits run as a single call so
                         they never pay the per-batch token overhead for a
                         marginal wall-clock gain. When fan-out does happen, the
                         batches are packed into at most AI_REVIEW_JOBS groups so
                         it always runs as one concurrent wave.
  AI_REVIEW_CONTEXT_BUDGET
                         Ceiling on how many context files the AI loads for one
                         call. The single-call path uses the skill default (15);
                         workers scale it down to their batch size to keep token
                         cost bounded.
  CI                     If "true", colors are suppressed and errors prefer the
                         fail-fast path.
  NO_COLOR               If set (any value), suppress ANSI color codes.

Exit codes:
  0   PASS or WARN (commit may proceed; or --dry-run / --no-block)
  1   BLOCK — findings require remediation; or unrecoverable runtime error
  2   Configuration error (AI_REVIEW_TOOL unset / invalid; bad flags)
EOF
}

# ── AI_REVIEW_TOOL validation ───────────────────────────────────────────────
# Resolves the tool name into AI_REVIEW_TOOL_RESOLVED (lower-cased, validated).
# Prints the resolved tool name for auditability on every run.
ai_review::resolve_tool() {
  if [[ -z "${AI_REVIEW_TOOL:-}" ]]; then
    ai_review::err "AI_REVIEW_TOOL environment variable is not set."
    ai_review::log ""
    ai_review::log "  This variable selects which AI coding assistant the hook will use."
    ai_review::log "  It must be set to exactly one of:  claude  |  codex  |  copilot"
    ai_review::log ""
    ai_review::log "  Set it for your current shell:"
    ai_review::log "      export AI_REVIEW_TOOL=claude     # (or codex / copilot)"
    ai_review::log ""
    ai_review::log "  Persist it across sessions (macOS, zsh):"
    ai_review::log "      echo 'export AI_REVIEW_TOOL=claude' >> ~/.zshrc"
    ai_review::log ""
    ai_review::log "  See the project README, section 'AI tool selection (AI_REVIEW_TOOL)'."
    exit 2
  fi

  # Lower-case for case-insensitive comparison.
  local raw="${AI_REVIEW_TOOL}"
  local lower
  lower="$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]')"

  case "${lower}" in
    claude|codex|copilot)
      AI_REVIEW_TOOL_RESOLVED="${lower}"
      ;;
    *)
      ai_review::err "AI_REVIEW_TOOL='${raw}' is not a recognized value."
      ai_review::log "  Valid values: claude | codex | copilot"
      exit 2
      ;;
  esac

  ai_review::info "AI tool resolved: ${AI_C_BLUE}${AI_REVIEW_TOOL_RESOLVED}${AI_C_RESET}"
}

# ── CLI presence checks ─────────────────────────────────────────────────────
ai_review::require_cli() {
  local tool="$1"
  local install_hint="$2"

  if ! command -v "${tool}" &>/dev/null; then
    ai_review::err "'${tool}' CLI not found on PATH."
    ai_review::log "  ${install_hint}"
    ai_review::log "  After installing, re-run:  pre-commit install"
    exit 1
  fi
}

# ── Diff collection ─────────────────────────────────────────────────────────
# Determines whether there are any changes to review.
# When AI_REVIEW_AGAINST is empty (default pre-commit mode), checks staged diff.
# When AI_REVIEW_AGAINST is set, checks the diff between that ref and HEAD.
# The :- defaults let these run safely under `set -u` in worker processes, which
# inherit AI_REVIEW_AGAINST from the environment rather than via parse_args.
ai_review::has_changes() {
  if [[ -n "${AI_REVIEW_AGAINST:-}" ]]; then
    if ! git rev-parse --verify --quiet "${AI_REVIEW_AGAINST}^{commit}" >/dev/null; then
      ai_review::err "Git ref not found: ${AI_REVIEW_AGAINST}"
      exit 1
    fi
    ! git diff --quiet "${AI_REVIEW_AGAINST}" HEAD --
  else
    ! git diff --cached --quiet
  fi
}

ai_review::changed_files() {
  if [[ -n "${AI_REVIEW_AGAINST:-}" ]]; then
    git diff --name-only "${AI_REVIEW_AGAINST}" HEAD --
  else
    git diff --cached --name-only
  fi
}

ai_review::diff_command_description() {
  if [[ -n "${AI_REVIEW_AGAINST:-}" ]]; then
    echo "git diff ${AI_REVIEW_AGAINST} HEAD"
  else
    echo "git diff --cached"
  fi
}

# ── Tool-specific invocation ────────────────────────────────────────────────
# Each ai_review::invoke_* function reads SKILL_PROMPT and prints the AI's raw
# response to stdout. Any non-zero exit from the underlying CLI is fatal.
#
# Why pass the full prompt rather than relying on auto-discovery:
# Only Claude Code has first-class skill auto-discovery. Codex and Copilot do
# not. For a uniform, reliable contract, every tool receives the same explicit
# prompt that references the SKILL.md path in that tool's standard location.

# ai_review::invoke_tool <prompt> [model]
# Invokes the resolved AI CLI in non-interactive mode with the given prompt,
# printing the raw response to stdout. When [model] is non-empty, it is passed
# to the CLI's model-selection flag — this is how the adjudication pass can run
# on a different model from the first pass while staying on the same CLI (a
# Claude shop has only the `claude` binary, so a cross-vendor second opinion is
# not assumed). Any non-zero exit from the underlying CLI propagates.
ai_review::invoke_tool() {
  local prompt="$1"
  local model="${2:-}"

  case "${AI_REVIEW_TOOL_RESOLVED}" in
    claude)
      ai_review::require_cli "claude" \
        "Install Claude Code:  npm install -g @anthropic-ai/claude-code"
      # -p = non-interactive (print) mode, exits after one response.
      if [[ -n "${model}" ]]; then
        claude -p "${prompt}" --model "${model}" 2>&1
      else
        claude -p "${prompt}" 2>&1
      fi
      ;;
    codex)
      ai_review::require_cli "codex" \
        "Install OpenAI Codex CLI:  npm install -g @openai/codex   (or see https://github.com/openai/codex)"
      # --sandbox read-only = filesystem read access (git diff / file reads)
      # with no write/network side effects, suitable for a pre-commit hook.
      if [[ -n "${model}" ]]; then
        codex exec --sandbox read-only --skip-git-repo-check --model "${model}" "${prompt}" 2>&1
      else
        codex exec --sandbox read-only --skip-git-repo-check "${prompt}" 2>&1
      fi
      ;;
    copilot)
      ai_review::require_cli "copilot" \
        "Install GitHub Copilot CLI (agentic):  https://github.com/github/copilot-cli"
      # copilot -p = non-interactive single-prompt mode.
      if [[ -n "${model}" ]]; then
        copilot -p "${prompt}" --model "${model}" 2>&1
      else
        copilot -p "${prompt}" 2>&1
      fi
      ;;
    *)
      ai_review::err "Internal error: unknown resolved tool '${AI_REVIEW_TOOL_RESOLVED}'"
      exit 1
      ;;
  esac
}

# First-pass invocation: the configured tool, its default model, the dispatcher's
# SKILL_PROMPT.
ai_review::invoke_ai() {
  ai_review::invoke_tool "${SKILL_PROMPT}" ""
}

# ── Result marker parsing ───────────────────────────────────────────────────
# The canonical marker is:  <<<AI_REVIEW_RESULT:PASS|WARN|BLOCK>>>
# We grep for the structured form first; if absent we fall through to a safety
# BLOCK because the AI must produce a marker and its absence indicates an error.
ai_review::parse_result() {
  local output="$1"

  if   grep -q '<<<AI_REVIEW_RESULT:BLOCK>>>' <<< "${output}"; then
    echo "BLOCK"
  elif grep -q '<<<AI_REVIEW_RESULT:WARN>>>'  <<< "${output}"; then
    echo "WARN"
  elif grep -q '<<<AI_REVIEW_RESULT:PASS>>>'  <<< "${output}"; then
    echo "PASS"
  else
    echo "UNPARSEABLE"
  fi
}

# ── Adjudication: false-positive reduction ──────────────────────────────────
# Two modes plus off, selected by AI_ADJUDICATION (default "self"):
#
#   self        Single-pass self-adjudication (DEFAULT, both pre-commit and
#               audit). The review prompt itself instructs the model to re-examine
#               its own candidate findings as a skeptic before reporting — one AI
#               call, no second invocation. Fastest/cheapest; catches the factual
#               false positives (synthetic/test data, already-mitigated,
#               misclassified) but is less independent than a fresh reviewer.
#   independent An additional fresh-agent second pass re-inspects a BLOCK/FINDINGS
#               result (the original behavior; honors AI_ADJUDICATION_MODEL so the
#               second opinion can run on a different model of the same CLI).
#               Strongest, but ~doubles time and cost on finding-bearing reviews.
#   off         No adjudication at all — raw first-pass findings, no self-critique.
#
# The --no-adjudicate flag (AI_REVIEW_NO_ADJUDICATE=1) forces "off". Skipping
# adjudication never lowers detection — it can only confirm/dismiss/downgrade —
# so "off" is the stricter (block-more) direction.

# ai_review::adjudication_mode  → prints one of: self | independent | off
# AI_ADJUDICATION accepts: self|inline, independent|fresh, off|0|no|none, and
# (back-compat) 1 → independent. Unknown values fall back to the safe default.
ai_review::adjudication_mode() {
  if [[ "${AI_REVIEW_NO_ADJUDICATE:-0}" == "1" ]]; then
    echo "off"; return 0
  fi
  local v
  v="$(printf '%s' "${AI_ADJUDICATION:-self}" | tr '[:upper:]' '[:lower:]')"
  case "${v}" in
    self|inline)         echo "self" ;;
    independent|fresh|1) echo "independent" ;;
    off|0|no|none|false) echo "off" ;;
    *)                   echo "self" ;;
  esac
}

# ai_review::self_adjudication_instructions
# Appended to every first-pass review prompt. The model applies it only when the
# AI_REVIEW_ADJUDICATION_MODE environment variable is "self" (the dispatchers
# export the resolved mode before invoking), so "independent"/"off" first passes
# report raw findings — independent runs its own separate pass, off skips it.
ai_review::self_adjudication_instructions() {
  cat <<'BLOCK'
SELF-ADJUDICATION — applies ONLY when the AI_REVIEW_ADJUDICATION_MODE environment
variable is "self" (its default). If that variable is "independent" or "off",
ignore this section and report your findings directly.

Before finalizing, re-examine your own candidate findings as a skeptical, second
reviewer. Inspect the actual cited code for each one and classify it:
  • CONFIRMED      — genuinely real at the stated severity; keep it.
  • OVERSTATED     — real but the severity is too high; keep it at the corrected
                     lower severity.
  • FALSE_POSITIVE — not a genuine issue; drop it.
The only legitimate grounds to dismiss or downgrade (do not invent others):
  • Synthetic / placeholder / obvious test data (example.com, 555 phone numbers,
    000-00-0000, AKIA…EXAMPLE keys, fixtures that are clearly not real secrets).
  • Already mitigated in the cited code (parameterized query, escaping/sanitizer,
    an authn/authz check that already guards the path).
  • Misclassification (a public identifier mistaken for a secret, and the like).
Keep any finding you cannot positively show to be benign — when in doubt, keep
it. Do NOT introduce new findings in this step.

Then report ONLY the confirmed findings, each at its final severity, and add a
short "Dismissed / downgraded (self-adjudication)" section listing what you
removed or lowered and why. Compute your end-of-response result marker from the
CONFIRMED findings only.
BLOCK
}

# Strip any result marker lines so an embedded first-pass report cannot be
# mistaken for the adjudicator's own (authoritative) marker.
ai_review::strip_markers() {
  sed -E '/<<<AI_REVIEW_RESULT:(PASS|WARN|BLOCK|CLEAN|FINDINGS)>>>/d'
}

# ai_review::extract_finding_paths <first_pass_report>
# Emits, one per line, the changed files that the first-pass report cites — used
# to scope the adjudication pass to just the finding-bearing code instead of the
# whole diff. We iterate the AUTHORITATIVE changed-file set (so prose tokens like
# "example.com" and hallucinated paths can never leak in) and keep a file if its
# path OR basename appears anywhere in the report (fixed-string match — no regex
# escaping pitfalls). Basename matching can mildly over-include on duplicate
# basenames, which is safe: it only widens the adjudicator's reading scope, it
# never drops a finding. Empty output means "couldn't determine" and the caller
# falls back to the whole diff (fail-safe — never under-review).
ai_review::extract_finding_paths() {
  local report="$1"
  local changed
  changed="$(ai_review::changed_files)"
  [[ -z "${changed}" ]] && return 0

  local cf base
  while IFS= read -r cf; do
    [[ -z "${cf}" ]] && continue
    base="$(basename "${cf}")"
    if grep -qF -- "${cf}" <<< "${report}" || grep -qF -- "${base}" <<< "${report}"; then
      printf '%s\n' "${cf}"
    fi
  done <<< "${changed}"
}

# ai_review::build_adjudication_prompt <first_pass_report> <markers> [scope_paths]
#   <markers>     is "pre-commit" (PASS/WARN/BLOCK) or "audit" (CLEAN/FINDINGS).
#   [scope_paths] (diff-mode only) newline-separated finding-bearing files; when
#                 non-empty the adjudicator is told to inspect only those.
ai_review::build_adjudication_prompt() {
  local report="$1"
  local markers="$2"
  local scope_paths="${3:-}"
  local clean_report
  clean_report="$(printf '%s\n' "${report}" | ai_review::strip_markers)"

  # What code the adjudicator must inspect. Audit-mode is already file-scoped by
  # the report. Diff-mode scopes to the finding-bearing files when we could parse
  # them; otherwise it falls back to the full diff (fail-safe).
  local code_scope_clause
  if [[ "${markers}" == "audit" ]]; then
    code_scope_clause="For audit-mode reviews the code under review is the files cited in the report."
  elif [[ -n "${scope_paths}" ]]; then
    local paths_inline
    paths_inline="$(printf '%s' "${scope_paths}" | tr '\n' ' ')"
    code_scope_clause="The first pass cited findings in these files ONLY — restrict your inspection to
them. Collect their diff with:
  git diff --cached -- ${paths_inline}
(or, if AI_REVIEW_AGAINST is set in your environment,
  git diff \$AI_REVIEW_AGAINST HEAD -- ${paths_inline}).
Do not review or report on files outside this set."
  else
    code_scope_clause="The code under review is, by default, the staged changes (\`git diff --cached\`);
if AI_REVIEW_AGAINST is set in your environment, it is \`git diff \$AI_REVIEW_AGAINST HEAD\`."
  fi

  local marker_instructions
  case "${markers}" in
    audit)
      marker_instructions="End your response with EXACTLY ONE of these markers, on its own line:
  <<<AI_REVIEW_RESULT:CLEAN>>>      — no confirmed findings remain at or above threshold
  <<<AI_REVIEW_RESULT:FINDINGS>>>   — one or more confirmed findings remain at or above threshold"
      ;;
    *)
      marker_instructions="End your response with EXACTLY ONE of these markers, on its own line:
  <<<AI_REVIEW_RESULT:PASS>>>    — no confirmed findings remain at any severity
  <<<AI_REVIEW_RESULT:WARN>>>    — only confirmed LOW findings remain
  <<<AI_REVIEW_RESULT:BLOCK>>>   — one or more confirmed Critical/High/Medium findings remain"
      ;;
  esac

  cat <<PROMPT
You have access to the finding-adjudication skill. Its full instructions are at:

  .skills/finding-adjudication/SKILL.md

(Tool-specific byte-identical copies may exist under .claude/, .codex/, or
.github/copilot/.)

Read that SKILL.md, then act as an INDEPENDENT second reviewer adjudicating the
findings produced by a first-pass automated review. You did not perform the
first pass and must not assume it was correct.

The code under review is the same code the first pass examined. ${code_scope_clause}
Inspect the actual code yourself before judging each finding — do not rely on
the report's summary.

For each finding in the first-pass report below, classify it as CONFIRMED,
FALSE_POSITIVE, or OVERSTATED (with a corrected lower severity), each with a
one-line rationale, following the finding-adjudication skill exactly. Do NOT
introduce new findings. Then produce the revised report in the format the skill
specifies: the surviving confirmed findings (at their final severity), followed
by a "Dismissed / Downgraded by adjudication" section that lists every change
with its reason, so nothing is silently removed.

Compute the result marker from the CONFIRMED findings only (after dismissals and
downgrades). ${marker_instructions}

If the first-pass report contains a SARIF block delimited by
<!-- AUDIT_SARIF_BEGIN --> and <!-- AUDIT_SARIF_END -->, emit an updated SARIF
block between the same delimiters reflecting only the confirmed findings at
their final severities.

──────────────────────── FIRST-PASS REPORT ────────────────────────
${clean_report}
────────────────────────────────────────────────────────────────────
PROMPT
}

# ai_review::adjudicate <first_pass_report> <markers>
# Runs the adjudication pass on the configured tool using AI_ADJUDICATION_MODEL
# (if set). Prints the adjudicated report to stdout; status logs go to stderr so
# callers can safely capture stdout.
ai_review::adjudicate() {
  local report="$1"
  local markers="${2:-pre-commit}"
  # Diff-mode: scope the second pass to the finding-bearing files (smaller,
  # faster, same model). Audit-mode is already file-scoped by its report.
  local scope_paths=""
  if [[ "${markers}" != "audit" ]]; then
    scope_paths="$(ai_review::extract_finding_paths "${report}")"
  fi
  local prompt
  prompt="$(ai_review::build_adjudication_prompt "${report}" "${markers}" "${scope_paths}")"
  ai_review::invoke_tool "${prompt}" "${AI_ADJUDICATION_MODEL:-}"
}

# ── Parallel fan-out for large diffs ─────────────────────────────────────────
# When a commit touches enough files across enough batches, split the diff into
# independent batches and review them concurrently, then fold the per-batch
# gate markers into one decision. Each worker runs the SAME first-pass →
# (BLOCK-only) adjudication sequence run() runs today, so quality and the gate
# are identical; only wall-clock changes. Mirrors the codebase-audit fan-out.

# ai_review::plan_diff_batches
# Emits one record per batch:  <key>\t<file>|<file>|...
# key = directory (default) or the file itself when AI_REVIEW_BATCH_BY=file.
# bash 3.2 safe: no associative arrays / mapfile — we emit <key>\t<file> pairs,
# sort (a tab-led sort groups a key's files together), then coalesce with awk.
#
# When a dispatcher defines SKILL_BATCH_FILE_FILTER_FN (a per-file predicate
# returning 0 to keep a file), only matching files are batched. code-security
# reviews everything (no filter); iac-compliance keeps only IaC files so fan-out
# never spins up a worker on a non-IaC directory.
ai_review::plan_diff_batches() {
  local by="${AI_REVIEW_BATCH_BY:-dir}"
  local filter_fn="${SKILL_BATCH_FILE_FILTER_FN:-}"
  ai_review::changed_files | while IFS= read -r f; do
    [[ -z "${f}" ]] && continue
    if [[ -n "${filter_fn}" ]] && declare -F "${filter_fn}" >/dev/null 2>&1; then
      "${filter_fn}" "${f}" || continue
    fi
    local key
    if [[ "${by}" == "file" ]]; then
      key="${f}"
    else
      key="$(dirname "${f}")"
      [[ "${key}" == "." ]] && key="(root)"
    fi
    printf '%s\t%s\n' "${key}" "${f}"
  done | LC_ALL=C sort | awk -F'\t' '
    {
      if ($1 != cur) {
        if (cur != "") { print cur "\t" files }
        cur = $1; files = $2
      } else {
        files = files "|" $2
      }
    }
    END { if (cur != "") print cur "\t" files }
  '
}

# ai_review::pack_batches <max_bins>   (reads <key>\t<files> records on stdin)
# Coalesces per-directory records into at most <max_bins> batches via greedy
# bin-packing (assign the largest remaining record to the least-loaded bin),
# balancing file counts. This is the cap that keeps fan-out to a SINGLE wave:
# without it, N directories become N batches that serialize into ceil(N/jobs)
# waves, each paying the full model cold-start + SKILL.md read — which made a
# many-directory commit *slower* than a single call. With batches ≤ jobs, every
# batch runs concurrently and wall-clock can't exceed a single full-diff call.
# bash 3.2 safe: all array work is in awk.
ai_review::pack_batches() {
  local max_bins="$1"
  awk -F'\t' -v N="${max_bins}" '
    {
      files=$2
      c=gsub(/\|/,"|",files)+1   # file count = (#pipes)+1; records are non-empty
      rkey[NR]=$1; rfiles[NR]=$2; rcnt[NR]=c; nrec=NR
    }
    END {
      if (N < 1) N=1
      if (nrec <= N) {           # already within the cap — pass through unchanged
        for (i=1;i<=nrec;i++) printf "%s\t%s\n", rkey[i], rfiles[i]
      } else {
        for (i=1;i<=N;i++) { load[i]=0; bin[i]="" }
        for (a=1;a<=nrec;a++) order[a]=a
        # selection sort by count desc (record counts are tiny)
        for (a=1;a<=nrec;a++) for (b=a+1;b<=nrec;b++)
          if (rcnt[order[b]]>rcnt[order[a]]) { t=order[a];order[a]=order[b];order[b]=t }
        for (a=1;a<=nrec;a++) {
          r=order[a]; m=1
          for (i=2;i<=N;i++) if (load[i]<load[m]) m=i
          bin[m] = (bin[m]=="") ? rfiles[r] : bin[m] "|" rfiles[r]
          load[m]+=rcnt[r]
        }
        b=0
        for (i=1;i<=N;i++) if (bin[i]!="") { b++; printf "batch %d (%d file(s))\t%s\n", b, load[i], bin[i] }
      }
    }
  '
}

# ai_review::should_batch <nfiles> <nbatches>
# Fan out only when it actually helps: more than one worker allowed, more than
# one batch to spread, and the diff is large enough to be worth the per-batch
# overhead. A single-directory change stays a single full-context call.
ai_review::should_batch() {
  local nfiles="$1" nbatches="$2"
  local min_files="${AI_REVIEW_BATCH_MIN_FILES:-10}"
  (( AI_REVIEW_JOBS > 1 )) && (( nbatches > 1 )) && (( nfiles >= min_files ))
}

# ai_review::context_budget <files_in_batch>
# A worker reviewing few files needs few context files. clamp(3 × n, 4, 15).
ai_review::context_budget() {
  local n="$1" b
  b=$(( 3 * n ))
  (( b < 4 ))  && b=4
  (( b > 15 )) && b=15
  printf '%s' "${b}"
}

# ai_review::fold_markers   (reads AI_REVIEW_BATCH_RESULT sentinel lines on stdin)
# Worst-of reduction: any BLOCK (or unparseable/blank) → BLOCK; else any WARN →
# WARN; else PASS. No sentinels at all → UNPARSEABLE (caller fails safe).
ai_review::fold_markers() {
  awk -F'\t' '
    $1 == "AI_REVIEW_BATCH_RESULT" {
      seen++
      m = $3
      if      (m == "BLOCK" || m == "UNPARSEABLE" || m == "") block=1
      else if (m == "WARN")  warn=1
      else if (m == "PASS")  pass=1
      else                   block=1
    }
    END {
      if      (block) print "BLOCK"
      else if (warn)  print "WARN"
      else if (pass)  print "PASS"
      else            print "UNPARSEABLE"
    }
  '
}

# ai_review::fan_out <record>...
# Re-invokes this skill's dispatcher (AI_REVIEW_SELF) once per batch via
# `xargs -0 -P AI_REVIEW_JOBS`. Each worker prints its human report to stderr
# (so it streams live) and exactly one sentinel line to stdout (captured here).
# Publishes the folded gate decision in AI_REVIEW_FOLDED_RESULT — returning it
# via a global keeps this function's own logging on stdout from polluting it.
ai_review::fan_out() {
  local -a records=("$@")
  local expected=${#records[@]}

  if [[ -z "${AI_REVIEW_SELF:-}" ]]; then
    ai_review::err "Internal error: AI_REVIEW_SELF not set; the dispatcher must export it for fan-out."
    AI_REVIEW_FOLDED_RESULT="BLOCK"
    return 0
  fi

  # Propagate config to the worker processes (they re-source this library).
  export AI_REVIEW_TOOL
  export AI_REVIEW_AGAINST
  export AI_REVIEW_BATCH_BY="${AI_REVIEW_BATCH_BY:-dir}"
  [[ "${AI_REVIEW_NO_ADJUDICATE:-0}" == "1" ]] && export AI_REVIEW_NO_ADJUDICATE
  [[ -n "${AI_ADJUDICATION:-}" ]]       && export AI_ADJUDICATION
  [[ -n "${AI_ADJUDICATION_MODEL:-}" ]] && export AI_ADJUDICATION_MODEL

  ai_review::info "Fanning out ${expected} batch(es) across ${AI_REVIEW_JOBS} workers (batch-by=${AI_REVIEW_BATCH_BY})..."

  local sentinels fan_rc=0
  # NUL-delimited records so embedded tabs/spaces in paths survive.
  sentinels="$(printf '%s\0' "${records[@]}" \
    | xargs -0 -P "${AI_REVIEW_JOBS}" -n1 bash "${AI_REVIEW_SELF}" --__review-one)" || fan_rc=$?

  local seen folded
  seen="$(printf '%s\n' "${sentinels}" | grep -c '^AI_REVIEW_BATCH_RESULT' || true)"
  folded="$(printf '%s\n' "${sentinels}" | ai_review::fold_markers)"

  # Fail-safe: a crashed worker (xargs returns 123) or a missing sentinel means
  # a batch was not reviewed — treat the whole commit as BLOCK rather than risk
  # letting unreviewed code through.
  if (( fan_rc != 0 )) || (( seen < expected )); then
    ai_review::warn "Some batches did not return a result (xargs rc=${fan_rc}; ${seen}/${expected} reported). Folding to BLOCK (fail-safe)."
    folded="BLOCK"
  fi

  ai_review::info "Per-batch results folded to: ${folded} (worst-of across ${expected} batch(es))."
  AI_REVIEW_FOLDED_RESULT="${folded}"
}

# ai_review::worker_main <record>
# The --__review-one entry point: reviews exactly one batch and prints a single
# sentinel line. The batch's paths are exposed to the AI via AI_REVIEW_SCOPE_PATHS
# and the context-file ceiling via AI_REVIEW_CONTEXT_BUDGET (both consulted by the
# SKILL_PROMPT). Runs first pass → BLOCK-only adjudication, exactly like run().
ai_review::worker_main() {
  local record="$1"
  ai_review::resolve_tool >/dev/null    # parent already announced the tool

  local key="${record%%$'\t'*}"
  local files_pipe="${record#*$'\t'}"
  local files_nl nfiles
  files_nl="$(printf '%s' "${files_pipe}" | tr '|' '\n' | grep -v '^$' || true)"
  nfiles="$(printf '%s\n' "${files_nl}" | grep -cv '^$' || true)"

  # Scope this worker to its files; everything to stderr except the sentinel.
  export AI_REVIEW_SCOPE_PATHS="${files_nl}"
  export AI_REVIEW_CONTEXT_BUDGET
  AI_REVIEW_CONTEXT_BUDGET="$(ai_review::context_budget "${nfiles}")"
  export AI_REVIEW_AGAINST
  # Tell the prompt which adjudication mode is in effect (self-critique applies
  # only in "self"). The first pass self-adjudicates in self mode; in
  # independent mode it reports raw and we run a separate pass below.
  local _adj_mode
  _adj_mode="$(ai_review::adjudication_mode)"
  export AI_REVIEW_ADJUDICATION_MODE="${_adj_mode}"

  local output rc=0 marker="UNPARSEABLE"
  output="$(ai_review::invoke_ai)" || rc=$?
  if (( rc != 0 )); then
    ai_review::err "[${key}] AI invocation failed (rc=${rc})." >&2
  else
    marker="$(ai_review::parse_result "${output}")"
    # Independent second opinion — only in independent mode, only on BLOCK.
    if [[ "${marker}" == "BLOCK" && "${_adj_mode}" == "independent" ]]; then
      ai_review::info "[${key}] BLOCK — running independent adjudication (second opinion)..." >&2
      local adj_output adj_rc=0 adj_marker=""
      adj_output="$(ai_review::adjudicate "${output}" "pre-commit")" || adj_rc=$?
      if (( adj_rc == 0 )); then
        adj_marker="$(ai_review::parse_result "${adj_output}")"
      fi
      if (( adj_rc != 0 )) || [[ "${adj_marker}" == "UNPARSEABLE" ]]; then
        ai_review::warn "[${key}] adjudication unavailable/unparseable; keeping first-pass BLOCK." >&2
      else
        output="${adj_output}"
        marker="${adj_marker}"
      fi
    fi
  fi

  # Human-readable report → stderr (streams live; never captured by the parent).
  {
    printf '\n──────── [%s] (%s file(s)) ────────\n' "${key}" "${nfiles}"
    printf '%s\n' "${output}"
  } >&2

  # Machine sentinel → stdout (the ONLY thing this process writes to stdout).
  printf 'AI_REVIEW_BATCH_RESULT\t%s\t%s\n' "${key}" "${marker}"
}

# ── Main entry point ────────────────────────────────────────────────────────
ai_review::run() {
  # Required-variable check.
  local missing=()
  [[ -z "${SKILL_NAME:-}"          ]] && missing+=("SKILL_NAME")
  [[ -z "${SKILL_HUMAN_NAME:-}"    ]] && missing+=("SKILL_HUMAN_NAME")
  [[ -z "${SKILL_PROMPT:-}"        ]] && missing+=("SKILL_PROMPT")
  if (( ${#missing[@]} > 0 )); then
    ai_review::err "Internal error: dispatcher library called without required variables: ${missing[*]}"
    exit 1
  fi

  # Parse args provided by the caller.
  ai_review::parse_args "$@"

  # If the dispatcher is configured to short-circuit on irrelevant files, run
  # that check before doing anything more expensive.
  if ! ai_review::has_changes; then
    ai_review::ok "No changes to review ($(ai_review::diff_command_description)) — skipping."
    exit 0
  fi

  if declare -F "${SKILL_FILE_FILTER_FN:-}" >/dev/null 2>&1; then
    if ! "${SKILL_FILE_FILTER_FN}"; then
      ai_review::ok "No relevant files in diff — skipping ${SKILL_NAME} review."
      exit 0
    fi
  fi

  # Resolve and announce the AI tool.
  ai_review::resolve_tool

  # ── Plan the batches (consulted by --list-batches, --dry-run, executor) ────
  local -a _batch_records=()
  local _rec
  while IFS= read -r _rec; do
    [[ -z "${_rec}" ]] && continue
    _batch_records+=("${_rec}")
  done < <(ai_review::plan_diff_batches)
  local _nbatches=${#_batch_records[@]}
  # Count files actually planned for review (post per-file filter), summed across
  # batches — not the raw changed-file count — so the threshold reflects the work
  # this skill will really do (e.g. iac-compliance counts only IaC files).
  local _nfiles=0 _fp _c
  for _rec in "${_batch_records[@]}"; do
    _fp="${_rec#*$'\t'}"
    _c="$(printf '%s' "${_fp}" | tr '|' '\n' | grep -cv '^$' || true)"
    _nfiles=$(( _nfiles + _c ))
  done

  # Cap the batch count to the worker count. If we're going to fan out and there
  # are more (per-directory/per-file) batches than workers, pack them into at
  # most AI_REVIEW_JOBS bins so execution is a SINGLE concurrent wave rather than
  # ceil(batches/jobs) waves that each re-pay the model cold-start. Without this,
  # an 11-file commit spread over 10 directories became 10 batches / 3 waves —
  # slower than one call. We decide on the raw batch count, then repack.
  if ai_review::should_batch "${_nfiles}" "${_nbatches}" && (( _nbatches > AI_REVIEW_JOBS )); then
    local -a _packed=()
    while IFS= read -r _rec; do
      [[ -z "${_rec}" ]] && continue
      _packed+=("${_rec}")
    done < <(printf '%s\n' "${_batch_records[@]}" | ai_review::pack_batches "${AI_REVIEW_JOBS}")
    _batch_records=("${_packed[@]}")
    _nbatches=${#_batch_records[@]}
  fi

  # --list-batches: print the plan and the routing decision; no AI call.
  if (( AI_REVIEW_LIST_BATCHES == 1 )); then
    ai_review::info "Batch plan (batch-by=${AI_REVIEW_BATCH_BY:-dir}): ${_nfiles} file(s) in ${_nbatches} batch(es)"
    for _rec in "${_batch_records[@]}"; do
      local _k="${_rec%%$'\t'*}" _fp="${_rec#*$'\t'}" _n
      _n="$(printf '%s' "${_fp}" | tr '|' '\n' | grep -cv '^$' || true)"
      printf '  %-50s %s file(s)\n' "${_k}" "${_n}"
    done
    if ai_review::should_batch "${_nfiles}" "${_nbatches}"; then
      ai_review::log "  → would FAN OUT across ${AI_REVIEW_JOBS} worker(s)."
    else
      ai_review::log "  → would run as a SINGLE call (needs jobs>1, >1 batch, and ≥${AI_REVIEW_BATCH_MIN_FILES:-10} files)."
    fi
    exit 0
  fi

  # Dry-run path: print plan, do not invoke AI.
  if (( AI_REVIEW_DRY_RUN == 1 )); then
    ai_review::info "DRY-RUN — no AI invocation will be made."
    ai_review::log  "  Skill:       ${SKILL_HUMAN_NAME} (${SKILL_NAME})"
    ai_review::log  "  AI tool:     ${AI_REVIEW_TOOL_RESOLVED}"
    ai_review::log  "  Diff source: $(ai_review::diff_command_description)"
    if ai_review::should_batch "${_nfiles}" "${_nbatches}"; then
      ai_review::log "  Routing:     FAN OUT — ${_nfiles} file(s) across ${_nbatches} batch(es), jobs=${AI_REVIEW_JOBS}"
    else
      ai_review::log "  Routing:     SINGLE call — ${_nfiles} file(s), ${_nbatches} batch(es)"
    fi
    ai_review::log  "  Changed files:"
    ai_review::changed_files | sed 's/^/    /'
    ai_review::log  ""
    ai_review::log  "  Prompt that would be sent to ${AI_REVIEW_TOOL_RESOLVED}:"
    ai_review::log  "  ────────────────────────────────────────────────────────────"
    printf '%s\n' "${SKILL_PROMPT}" | sed 's/^/    /'
    ai_review::log  "  ────────────────────────────────────────────────────────────"
    exit 0
  fi

  # Export AI_REVIEW_AGAINST so the AI subprocess can see it (it tells the AI
  # which git diff range to use; the skill consults this variable).
  export AI_REVIEW_AGAINST

  # Resolve the adjudication mode once. The prompt's self-adjudication block
  # applies only when AI_REVIEW_ADJUDICATION_MODE is "self"; the independent
  # second pass below runs only in "independent" mode. (Fan-out workers resolve
  # and export this themselves; we export here for the single-call path.)
  local _adj_mode
  _adj_mode="$(ai_review::adjudication_mode)"
  export AI_REVIEW_ADJUDICATION_MODE="${_adj_mode}"

  local result

  if ai_review::should_batch "${_nfiles}" "${_nbatches}"; then
    # ── Parallel fan-out path ──────────────────────────────────────────────
    # Each batch runs the same first-pass → BLOCK-only adjudication sequence the
    # single-call path runs; ai_review::fan_out folds the per-batch markers
    # (worst-of) into AI_REVIEW_FOLDED_RESULT.
    ai_review::info "Running ${SKILL_HUMAN_NAME} on $(ai_review::diff_command_description) via ${AI_REVIEW_TOOL_RESOLVED} — ${_nfiles} file(s) across ${_nbatches} batch(es)..."
    ai_review::log  "────────────────────────────────────────────────────────────"
    AI_REVIEW_FOLDED_RESULT=""
    ai_review::fan_out "${_batch_records[@]}"
    result="${AI_REVIEW_FOLDED_RESULT}"
    ai_review::log  "────────────────────────────────────────────────────────────"
  else
    # ── Single-call path (full diff in one review) ─────────────────────────
    ai_review::info "Running ${SKILL_HUMAN_NAME} on $(ai_review::diff_command_description) via ${AI_REVIEW_TOOL_RESOLVED}..."
    ai_review::log  "────────────────────────────────────────────────────────────"

    local review_output invoke_rc=0
    # set -e is in effect, so wrap the call to inspect the exit code.
    review_output="$(ai_review::invoke_ai)" || invoke_rc=$?

    printf '%s\n' "${review_output}"
    ai_review::log  "────────────────────────────────────────────────────────────"

    if (( invoke_rc != 0 )); then
      ai_review::err "AI CLI (${AI_REVIEW_TOOL_RESOLVED}) exited with code ${invoke_rc}."
      ai_review::log "  Treating as BLOCK to fail safe."
      if (( AI_REVIEW_NO_BLOCK == 1 )); then
        ai_review::warn "--no-block in effect: not blocking despite CLI failure."
        exit 0
      fi
      exit 1
    fi

    result="$(ai_review::parse_result "${review_output}")"

    # Independent second-opinion adjudication. Runs only in "independent" mode
    # and only on a BLOCK first pass (PASS/WARN proceed regardless, so a second
    # pass could not change the gate). In the default "self" mode the first pass
    # has already self-adjudicated in a single call, so there is no second call.
    if [[ "${result}" == "BLOCK" && "${_adj_mode}" == "independent" ]]; then
      ai_review::info "First pass result: ${result}. Running independent adjudication (second opinion)${AI_ADJUDICATION_MODEL:+ via model ${AI_ADJUDICATION_MODEL}}..."
      local adj_output adj_rc=0
      adj_output="$(ai_review::adjudicate "${review_output}" "pre-commit")" || adj_rc=$?

      if (( adj_rc != 0 )); then
        ai_review::warn "Adjudication pass failed (rc=${adj_rc}); keeping the first-pass result (${result})."
      else
        ai_review::log  "──────── Adjudication (independent second opinion) ────────"
        printf '%s\n' "${adj_output}"
        ai_review::log  "────────────────────────────────────────────────────────────"
        local adj_result
        adj_result="$(ai_review::parse_result "${adj_output}")"
        if [[ "${adj_result}" == "UNPARSEABLE" ]]; then
          ai_review::warn "Adjudication produced no parseable result marker; keeping the first-pass result (${result})."
        else
          ai_review::info "Adjudicated result: ${result} → ${adj_result} (gate decided by adjudication)."
          result="${adj_result}"
        fi
      fi
    fi
  fi

  # Act on the (possibly adjudicated / folded) result marker.
  case "${result}" in
    PASS)
      ai_review::ok "${AI_C_BOLD}✅  ${SKILL_HUMAN_NAME} passed. No findings detected.${AI_C_RESET}"
      exit 0
      ;;
    WARN)
      ai_review::warn "${AI_C_BOLD}⚠️   ${SKILL_HUMAN_NAME} warnings found. Review the report above before proceeding.${AI_C_RESET}"
      ai_review::warn "Low-severity findings only. Commit is allowed."
      exit 0
      ;;
    BLOCK)
      ai_review::err "${AI_C_BOLD}🚫  COMMIT BLOCKED — Critical, high, or medium findings detected.${AI_C_RESET}"
      ai_review::err "Resolve all critical, high, and medium findings before committing."
      ai_review::err "See the report above for details and remediation guidance."
      ai_review::err "If you believe this is a false positive, see the README section on false positives."
      if (( AI_REVIEW_NO_BLOCK == 1 )); then
        ai_review::warn "--no-block in effect: not blocking despite BLOCK result."
        exit 0
      fi
      exit 1
      ;;
    UNPARSEABLE|*)
      ai_review::err "Could not parse review result."
      ai_review::log "  Expected one of:"
      ai_review::log "      <<<AI_REVIEW_RESULT:PASS>>>"
      ai_review::log "      <<<AI_REVIEW_RESULT:WARN>>>"
      ai_review::log "      <<<AI_REVIEW_RESULT:BLOCK>>>"
      ai_review::log "  None of these markers were present in the AI's response."
      ai_review::log "  This usually indicates the AI CLI encountered an error or the prompt was modified."
      ai_review::log "  Failing safe (BLOCK)."
      if (( AI_REVIEW_NO_BLOCK == 1 )); then
        ai_review::warn "--no-block in effect: not blocking despite unparseable result."
        exit 0
      fi
      exit 1
      ;;
  esac
}
