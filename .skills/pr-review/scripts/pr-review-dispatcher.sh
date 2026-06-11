#!/usr/bin/env bash
# .skills/pr-review/scripts/pr-review-dispatcher.sh
#
# PR-review dispatcher. Composes security + compliance perspectives into a
# single PR review and (optionally) posts inline review comments to GitHub
# via the `gh` CLI.
#
# This dispatcher differs from the pre-commit dispatchers in three ways:
#
#   1. It computes its diff range from a pull-request base ref, not from the
#      git index. Auto-discovery uses `gh pr view`; manual override via --pr.
#   2. It parses a JSON intermediate format from the AI's response and uses
#      the GitHub REST API (via `gh api`) to post one review with multiple
#      inline comments — proper `code suggestion` blocks that PR authors can
#      one-click apply.
#   3. By default the dispatcher exits 0 even when findings exist; PR review
#      is advisory. The --gate flag flips this to exit 1 on non-APPROVE,
#      which is the CI-blocking mode.
#
# Usage:
#   pr-review-dispatcher.sh                          # auto-discover PR; print only
#   pr-review-dispatcher.sh --post-comments          # also post inline comments
#   pr-review-dispatcher.sh --pr 1234                # explicit PR number
#   pr-review-dispatcher.sh --against origin/main    # explicit base ref
#   pr-review-dispatcher.sh --gate                   # exit 1 on non-APPROVE
#   pr-review-dispatcher.sh --dry-run                # show plan, no AI call
#
# Required environment:
#   AI_REVIEW_TOOL          claude | codex | copilot
#
# Required when --post-comments is used:
#   gh CLI installed and authenticated; or GH_TOKEN exported

set -euo pipefail

# ── Resolve repository root and shared library ─────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
fi
LIB_PATH="${REPO_ROOT}/.skills/_lib/ai-review-dispatch.sh"

if [[ ! -f "${LIB_PATH}" ]]; then
  echo "ERROR: shared dispatch library not found at: ${LIB_PATH}" >&2
  echo "       This file is required. Re-install the skills (see README.md)." >&2
  exit 1
fi

# ── Skill identity ──────────────────────────────────────────────────────────
SKILL_NAME="pr-review"
SKILL_HUMAN_NAME="AI-Assisted PR Review (security + compliance)"
SKILL_PATH_CANONICAL=".skills/pr-review/SKILL.md"

# ── PR-review-specific arg parsing ─────────────────────────────────────────
# We extend the shared library's arg parser by intercepting our own flags
# first, then passing the remainder to the library's parser via positional
# rewrite. Recognized flags here:
#
#   --pr <number>         Explicit PR number (overrides auto-discovery)
#   --post-comments       Post inline review via gh api
#   --gate                Exit 1 if review_action != APPROVE
#   --json-only           Print only the JSON block (machine consumption)
#
# All other flags fall through to the shared library.

PR_NUMBER=""
POST_COMMENTS=0
GATE_MODE=0
JSON_ONLY=0
REMAINING_FOR_LIB=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      if [[ -z "${2:-}" ]] || [[ ! "${2}" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --pr requires a numeric PR number" >&2
        exit 2
      fi
      PR_NUMBER="$2"
      shift 2
      ;;
    --pr=*)
      PR_NUMBER="${1#*=}"
      if [[ ! "${PR_NUMBER}" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --pr requires a numeric PR number" >&2
        exit 2
      fi
      shift
      ;;
    --post-comments)
      POST_COMMENTS=1
      shift
      ;;
    --gate)
      GATE_MODE=1
      shift
      ;;
    --json-only)
      JSON_ONLY=1
      shift
      ;;
    *)
      REMAINING_FOR_LIB+=("$1")
      shift
      ;;
  esac
done

# ── Discover PR and base ref ────────────────────────────────────────────────
# If --against was passed (will be captured by the library's parser later), it
# wins. Otherwise we ask gh for the PR's baseRefName. Otherwise we error.
ai_review::discover_pr_context() {
  # Check if the library already resolved an --against ref by peeking at the
  # remaining args.
  for arg in "${REMAINING_FOR_LIB[@]}"; do
    if [[ "${arg}" == "--against" ]] || [[ "${arg}" == --against=* ]]; then
      # --against will be parsed by the library; we don't need to discover
      return 0
    fi
  done

  # If --pr was given, look up that PR's base ref.
  if [[ -n "${PR_NUMBER}" ]]; then
    require_gh_cli "PR number was specified via --pr"
    local base
    base="$(gh pr view "${PR_NUMBER}" --json baseRefName --jq '.baseRefName' 2>/dev/null || true)"
    if [[ -z "${base}" ]]; then
      echo "ERROR: could not look up PR #${PR_NUMBER} via gh CLI." >&2
      echo "       Verify the PR number exists and you have access to it." >&2
      exit 1
    fi
    REMAINING_FOR_LIB+=("--against" "origin/${base}")
    AI_REVIEW_PR_NUMBER="${PR_NUMBER}"
    AI_REVIEW_PR_BASE="${base}"
    return 0
  fi

  # Otherwise auto-discover from the current branch.
  if ! command -v gh &>/dev/null; then
    echo "ERROR: cannot auto-discover the PR for the current branch — 'gh' CLI not installed." >&2
    echo "" >&2
    echo "  You have three options:" >&2
    echo "    1. Install gh and authenticate:  brew install gh && gh auth login" >&2
    echo "    2. Specify a PR explicitly:      --pr <number>" >&2
    echo "    3. Specify a base ref directly:  --against origin/main" >&2
    exit 1
  fi

  local pr_json
  if ! pr_json="$(gh pr view --json number,baseRefName 2>/dev/null)"; then
    echo "ERROR: 'gh pr view' could not find an open PR for the current branch." >&2
    echo "" >&2
    echo "  Either:" >&2
    echo "    • Push your branch and open a PR, then re-run; or" >&2
    echo "    • Specify the PR number explicitly:   --pr <number>" >&2
    echo "    • Specify the base ref directly:      --against origin/main" >&2
    exit 1
  fi

  AI_REVIEW_PR_NUMBER="$(echo "${pr_json}" | sed -n 's/.*"number":\([0-9]*\).*/\1/p')"
  AI_REVIEW_PR_BASE="$(echo  "${pr_json}" | sed -n 's/.*"baseRefName":"\([^"]*\)".*/\1/p')"

  if [[ -z "${AI_REVIEW_PR_NUMBER}" ]] || [[ -z "${AI_REVIEW_PR_BASE}" ]]; then
    echo "ERROR: failed to parse PR number / base ref from 'gh pr view' output." >&2
    exit 1
  fi

  REMAINING_FOR_LIB+=("--against" "origin/${AI_REVIEW_PR_BASE}")
  echo "[pr-review] Auto-discovered PR #${AI_REVIEW_PR_NUMBER} (base: ${AI_REVIEW_PR_BASE})"
}

require_gh_cli() {
  local why="$1"
  if ! command -v gh &>/dev/null; then
    echo "ERROR: 'gh' CLI is required (${why}) but is not installed." >&2
    echo "       Install:  brew install gh   (macOS)" >&2
    echo "       Then:     gh auth login" >&2
    echo "       Or set a fine-grained PAT via the GH_TOKEN env var." >&2
    exit 1
  fi
  if ! gh auth status &>/dev/null; then
    echo "ERROR: 'gh' CLI is installed but not authenticated." >&2
    echo "       Run:  gh auth login" >&2
    echo "       Or set the GH_TOKEN environment variable." >&2
    exit 1
  fi
}

# ── Prompt construction ─────────────────────────────────────────────────────
# We instruct the AI to emit BOTH a human-readable report AND a fenced JSON
# block. The dispatcher extracts the JSON block to post via the GitHub API.

read -r -d '' SKILL_PROMPT <<'PROMPT' || true
You have access to the pr-review skill. The skill's full instructions are in
this repository at:

  .skills/pr-review/SKILL.md

(Tool-specific copies may also exist at .claude/skills/pr-review/SKILL.md,
.codex/skills/pr-review/SKILL.md, or .github/copilot/skills/pr-review/SKILL.md;
all are byte-identical to the canonical file above.)

This skill is a composed PR review. You will additionally need to read:

  .skills/code-security/SKILL.md      (security perspective)
  .skills/iac-compliance/SKILL.md     (compliance perspective)

Run a full PR review on the diff between AI_REVIEW_AGAINST and HEAD:

  git diff "$AI_REVIEW_AGAINST" HEAD --unified=5
  git diff "$AI_REVIEW_AGAINST" HEAD --name-only

Follow the skill instructions in pr-review/SKILL.md exactly:

  1. Collect the PR diff.
  2. Determine which perspectives apply (security always; compliance only if
     IaC files are present).
  3. Load up to 15 targeted context files per perspective.
  4. Apply each perspective's full check list to the diff.
  5. Emit a human-readable terminal report (formatted markdown).
  6. After the report, emit ONE machine-readable JSON block delimited by
     these exact markers on their own lines:

       <!-- AI_REVIEW_JSON_BEGIN -->
       { ...JSON object as specified in pr-review/SKILL.md... }
       <!-- AI_REVIEW_JSON_END -->

     The JSON object must have the schema documented in pr-review/SKILL.md
     section "6B — Machine-Readable JSON Block".

After the JSON block, end your response with EXACTLY ONE of the following
markers, on its own line, with no surrounding text:

  <<<AI_REVIEW_RESULT:APPROVE>>>           (only if zero findings)
  <<<AI_REVIEW_RESULT:COMMENT>>>           (any findings, advisory)

Do NOT emit <<<AI_REVIEW_RESULT:REQUEST_CHANGES>>> from the AI side. That
result is reserved for the dispatcher's --gate mode.

The marker must match the "review_action" field in the JSON block. Failure
to emit a marker, or mismatch between the marker and the JSON, will cause
the dispatcher to log an error and exit non-zero.
PROMPT

# ── Source shared library and override the run function ─────────────────────
# shellcheck source=../../_lib/ai-review-dispatch.sh
source "${LIB_PATH}"

# ── Helpers: JSON extraction and PR review posting ─────────────────────────

# Pull the JSON block between AI_REVIEW_JSON_BEGIN/END markers out of stdin.
#
# We deliberately return only the LAST closed marker pair. Some CLIs (notably
# `codex exec`, whose stdout we capture via 2>&1) echo the dispatcher's own
# instructions back in their output — and those instructions contain a literal
# example of the markers wrapping a placeholder line ("{ ...JSON object... }").
# A naive "print every captured line" would concatenate that placeholder with
# the real JSON, and the placeholder lands first, so the JSON parser dies on it.
# The real JSON is always emitted last (after the human report), so the last
# fully-closed block is the authoritative one.
extract_review_json() {
  local input="$1"
  echo "${input}" | awk '
    /<!-- AI_REVIEW_JSON_BEGIN -->/ { capturing=1; block=""; next }
    /<!-- AI_REVIEW_JSON_END -->/   { if (capturing) { last=block; have=1 } capturing=0; next }
    capturing                       { block = block $0 "\n" }
    END                             { if (have) printf "%s", last }
  '
}

# Render one comment body in Conventional Comments + suggestion format.
# Args: perspective severity title description suggestion_kind suggestion_language suggestion_body
render_comment_body() {
  local perspective="$1"
  local severity="$2"
  local title="$3"
  local description="$4"
  local kind="$5"
  local lang="$6"
  local body="$7"

  local sev_lc
  sev_lc="$(printf '%s' "${severity}" | tr '[:upper:]' '[:lower:]')"

  local fence_lang
  if [[ "${kind}" == "applicable" ]]; then
    fence_lang="suggestion"
  else
    fence_lang="${lang}"
  fi

  cat <<EOF
${perspective}(${sev_lc}): ${title}

Description: ${description}

Severity: ${severity}

Suggestion:

\`\`\`${fence_lang}
${body}
\`\`\`

_Reviewed by AI, was this helpful? Please react with 👍 or 👎._
EOF
}

# Post the review to GitHub. Requires: PR number, repo, gh cli authed,
# and review JSON on stdin.
post_review_to_github() {
  local pr_number="$1"
  local review_json="$2"

  require_gh_cli "--post-comments was specified"

  # Resolve owner/repo from gh's view of the current repo.
  local repo_slug
  if ! repo_slug="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)"; then
    echo "ERROR: could not determine repo from gh CLI." >&2
    exit 1
  fi

  # The dispatcher constructs a GitHub-API payload from the AI's JSON, then
  # POSTs to /repos/{owner}/{repo}/pulls/{n}/reviews. We use python for JSON
  # transformation since pure-bash JSON manipulation is brittle.
  if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required to post inline review comments." >&2
    echo "       (Used for transforming AI JSON output → GitHub API payload.)" >&2
    exit 1
  fi

  # Idempotency: fetch the AI reviewer's existing inline comments so the payload
  # builder can drop any finding that already carries a live comment on an
  # unchanged line. Streamed as NDJSON via gh's built-in jq (one object/line
  # across all pages — avoids the concatenated-array invalid-JSON problem). A
  # fetch failure degrades safely to empty (no de-dup), never blocking the post.
  local existing_comments
  existing_comments="$(gh api --paginate \
    "repos/${repo_slug}/pulls/${pr_number}/comments" \
    --jq '.[] | {path: .path, line: .line, body: .body}' 2>/dev/null || true)"
  export AI_REVIEW_EXISTING_COMMENTS="${existing_comments}"

  # Diff positions: fetch the PR's per-file patches so the payload builder can
  # drop any finding whose line is not part of the diff. GitHub rejects the
  # ENTIRE review (HTTP 422) if a single inline comment lands on a line outside
  # the diff, so we filter to commentable positions before posting. NDJSON, one
  # object per file. A fetch failure degrades to no filtering — the body-only
  # POST fallback below still protects the run.
  local pr_files
  pr_files="$(gh api --paginate \
    "repos/${repo_slug}/pulls/${pr_number}/files" \
    --jq '.[] | {filename: .filename, patch: .patch}' 2>/dev/null || true)"
  export AI_REVIEW_PR_FILES="${pr_files}"

  local api_payload
  api_payload="$(echo "${review_json}" | python3 -c '
import json, sys, html, os, re

try:
    data = json.load(sys.stdin)
except Exception as e:
    print(f"ERROR: could not parse review JSON from AI output: {e}", file=sys.stderr)
    sys.exit(1)

action = data.get("review_action", "COMMENT")
summary = data.get("summary", "AI-assisted PR review (security + compliance).")
comments_in = data.get("comments", [])

# ── Idempotency: build the set of lines that already carry a live AI comment ──
# An existing comment is a de-dup anchor only if (a) it is one of ours (carries
# the attribution marker) and (b) GitHub still positions it on the current diff
# (line is not null). When a line or its hunk changes, GitHub outdates the
# comment (line -> null), so it stops anchoring and we re-comment automatically.
# Key is (path, line, perspective): perspective is stable across runs, so a
# security and a compliance finding on the same line both survive, while a
# repeat within one perspective is suppressed. Titles are intentionally NOT in
# the key — runs are non-deterministic and reword titles for the same issue.
ATTRIBUTION_MARKER = "Reviewed by AI"

def perspective_of(body):
    lines = (body or "").strip().splitlines()
    first = lines[0] if lines else ""
    m = re.match(r"\s*(security|compliance)\s*\(", first, re.I)
    return m.group(1).lower() if m else None

anchored = set()
for raw in os.environ.get("AI_REVIEW_EXISTING_COMMENTS", "").splitlines():
    raw = raw.strip()
    if not raw:
        continue
    try:
        ec = json.loads(raw)
    except Exception:
        continue
    body = ec.get("body") or ""
    if ATTRIBUTION_MARKER not in body:   # not one of ours
        continue
    ln = ec.get("line")
    if ln is None:                       # outdated → line changed → re-comment
        continue
    anchored.add((ec.get("path"), ln, perspective_of(body)))

AI_ATTRIBUTION = (
    "_Reviewed by AI, was this helpful? Please react with "
    "\U0001F44D or \U0001F44E._"
)
# Append the attribution as the final line of the top-level review body.
# Guard against duplication if the AI already included it in the JSON summary.
if AI_ATTRIBUTION not in summary:
    summary = summary.rstrip() + "\n\n" + AI_ATTRIBUTION

def render_body(c):
    perspective = c.get("perspective", "security")
    severity = c.get("severity", "LOW").upper()
    sev_lc = severity.lower()
    title = c.get("title", "Finding")
    description = c.get("description", "")
    kind = c.get("suggestion_kind", "reference")
    body = c.get("suggestion_body", "")
    if kind == "applicable":
        fence = "suggestion"
    else:
        fence = c.get("suggestion_language", "")
    return (
        f"{perspective}({sev_lc}): {title}\n\n"
        f"Description: {description}\n\n"
        f"Severity: {severity}\n\n"
        f"Suggestion:\n\n"
        f"```{fence}\n{body}\n```\n\n"
        f"_Reviewed by AI, was this helpful? Please react with \U0001F44D or \U0001F44E._\n"
    )

# ── Diff positions: which (path, line, side) are commentable ─────────────────
# GitHub rejects the ENTIRE review (HTTP 422) if any inline comment lands on a
# line that is not part of the diff. Parse each file patch into the set of
# new-file lines (RIGHT: added + context) and old-file lines (LEFT: removed +
# context); findings outside those sets get moved into the review body instead.
# If the files fetch returned nothing, have_diff stays False and filtering is
# skipped (the body-only POST fallback still protects the run).
right_lines = {}
left_lines = {}
have_diff = False

def parse_patch(patch):
    right, left = set(), set()
    new_ln = old_ln = None
    for pl in patch.split("\n"):
        if pl.startswith("@@"):
            m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", pl)
            if m:
                old_ln = int(m.group(1)); new_ln = int(m.group(2))
            continue
        if new_ln is None:
            continue
        if pl.startswith("+"):
            right.add(new_ln); new_ln += 1
        elif pl.startswith("-"):
            left.add(old_ln); old_ln += 1
        elif pl.startswith(" "):
            right.add(new_ln); left.add(old_ln); new_ln += 1; old_ln += 1
    return right, left

for raw in os.environ.get("AI_REVIEW_PR_FILES", "").splitlines():
    raw = raw.strip()
    if not raw:
        continue
    try:
        pf = json.loads(raw)
    except Exception:
        continue
    fn = pf.get("filename")
    patch = pf.get("patch")
    if not fn or not patch:
        continue
    have_diff = True
    r, l = parse_patch(patch)
    right_lines.setdefault(fn, set()).update(r)
    left_lines.setdefault(fn, set()).update(l)

def in_diff(path, line, side):
    if not have_diff:
        return True   # no diff info available → do not filter
    if side == "LEFT":
        return line in left_lines.get(path, set())
    return line in right_lines.get(path, set())

comments_out = []
suppressed = 0
out_of_diff = []
for c in comments_in:
    if not all(k in c for k in ("path", "line", "perspective", "severity", "title", "description")):
        print(f"WARN: skipping malformed comment: {c}", file=sys.stderr)
        continue
    key = (c["path"], c["line"], (c.get("perspective") or "security").lower())
    if key in anchored:
        suppressed += 1
        continue
    side = c.get("side", "RIGHT")
    if not in_diff(c["path"], c["line"], side):
        out_of_diff.append(c)
        continue
    comments_out.append({
        "path": c["path"],
        "line": c["line"],
        "side": side,
        "body": render_body(c),
    })

if suppressed:
    print(f"[pr-review] Suppressed {suppressed} finding(s) already posted on "
          f"unchanged lines.", file=sys.stderr)

# Findings whose line is not in the diff cannot be inline-anchored (GitHub would
# 422 the whole review). Surface them in the review body so they are not lost.
if out_of_diff:
    print(f"[pr-review] {len(out_of_diff)} finding(s) reference lines outside the "
          f"PR diff; moving them into the review body.", file=sys.stderr)
    md = []
    for c in out_of_diff:
        persp = (c.get("perspective") or "security").lower()
        sev = str(c.get("severity", "LOW")).lower()
        cpath = c.get("path")
        cline = c.get("line")
        ctitle = c.get("title", "Finding")
        md.append(f"- **{persp}({sev})** `{cpath}:{cline}` - {ctitle}")
    summary = (summary.rstrip()
               + "\n\n---\n\n#### Findings outside the diff (not inline-anchored)\n\n"
               + "\n".join(md))

# If there is genuinely nothing new to post — everything already commented on
# unchanged lines, and nothing was moved to the body — skip the redundant empty
# COMMENT review. The bash caller treats this sentinel as a clean no-op. APPROVE
# is left alone: it carries no inline comments and re-approving is harmless.
if action == "COMMENT" and not comments_out and not out_of_diff:
    print("__AI_REVIEW_SKIP_POST__")
    print("[pr-review] All findings already posted on unchanged lines; "
          "nothing new to comment.", file=sys.stderr)
    sys.exit(0)

payload = {
    "event": action if action in ("APPROVE", "COMMENT", "REQUEST_CHANGES") else "COMMENT",
    "body": summary,
    "comments": comments_out,
}
print(json.dumps(payload))
')"

  if [[ "${api_payload}" == "__AI_REVIEW_SKIP_POST__" ]]; then
    echo "[pr-review] No new findings to post (all already commented on unchanged lines)."
    return 0
  fi

  if [[ -z "${api_payload}" ]]; then
    echo "ERROR: failed to construct GitHub API payload." >&2
    exit 1
  fi

  echo "[pr-review] Posting review to ${repo_slug} PR #${pr_number} via gh api..."
  local resp rc=0
  resp="$(echo "${api_payload}" | gh api \
        "repos/${repo_slug}/pulls/${pr_number}/reviews" \
        --method POST --input - 2>&1)" || rc=$?
  if (( rc == 0 )); then
    echo "[pr-review] Review posted."
    return 0
  fi

  # Non-zero: GitHub rejected the request. Surface its actual message — a 422
  # here is almost always an invalid review PAYLOAD (most often an inline comment
  # on a line not in the diff), NOT an auth problem (that would be 401 / 403).
  echo "[pr-review] GitHub rejected the review:" >&2
  printf '%s\n' "${resp}" | sed "s/^/    /" >&2

  # Fallback: if the payload carried inline comments, retry body-only so the
  # summary review still lands instead of failing the build outright.
  if ! printf '%s' "${api_payload}" | grep -q '"comments": \[\]'; then
    echo "[pr-review] Retrying as a summary-only review (dropping inline comments)..." >&2
    local body_only rc2=0 resp2
    body_only="$(printf '%s' "${api_payload}" | python3 -c 'import json,sys; d=json.load(sys.stdin); d["comments"]=[]; print(json.dumps(d))')" || body_only=""
    if [[ -n "${body_only}" ]]; then
      resp2="$(echo "${body_only}" | gh api \
            "repos/${repo_slug}/pulls/${pr_number}/reviews" \
            --method POST --input - 2>&1)" || rc2=$?
      if (( rc2 == 0 )); then
        echo "[pr-review] Posted a summary-only review (inline comments dropped; findings are in the body)."
        return 0
      fi
      echo "[pr-review] Summary-only retry also failed:" >&2
      printf '%s\n' "${resp2}" | sed "s/^/    /" >&2
    fi
  fi

  echo "ERROR: could not post the review via 'gh api' (see GitHub's message above)." >&2
  echo "       HTTP 422 = invalid review payload (commonly a comment line not in the diff)." >&2
  echo "       HTTP 401 / 403 = auth / permissions (token needs 'pull-requests: write')." >&2
  exit 1
}

# ── Custom run loop ────────────────────────────────────────────────────────
# We can't use ai_review::run as-is because we need to:
#   1. Inject PR discovery before the diff is computed
#   2. Extract and post the JSON block after the AI returns
#   3. Apply --gate exit semantics
# So we duplicate the control flow with the PR-specific additions.

pr_review::run() {
  # Discover the PR (and inject --against into REMAINING_FOR_LIB).
  ai_review::discover_pr_context

  # Hand off remaining args to the library's parser.
  ai_review::parse_args "${REMAINING_FOR_LIB[@]+"${REMAINING_FOR_LIB[@]}"}"

  if ! ai_review::has_changes; then
    ai_review::ok "No changes to review ($(ai_review::diff_command_description)) — skipping."
    exit 0
  fi

  ai_review::resolve_tool

  if (( AI_REVIEW_DRY_RUN == 1 )); then
    ai_review::info "DRY-RUN — no AI invocation will be made."
    ai_review::log  "  Skill:          ${SKILL_HUMAN_NAME} (${SKILL_NAME})"
    ai_review::log  "  AI tool:        ${AI_REVIEW_TOOL_RESOLVED}"
    ai_review::log  "  PR number:      ${AI_REVIEW_PR_NUMBER:-(none — using --against directly)}"
    ai_review::log  "  Diff source:    $(ai_review::diff_command_description)"
    ai_review::log  "  Post comments:  $((POST_COMMENTS == 1 ? POST_COMMENTS : 0))"
    ai_review::log  "  Gate mode:      $((GATE_MODE == 1 ? GATE_MODE : 0))"
    ai_review::log  "  Changed files:"
    ai_review::changed_files | sed 's/^/    /'
    exit 0
  fi

  ai_review::info "Running ${SKILL_HUMAN_NAME} on $(ai_review::diff_command_description) via ${AI_REVIEW_TOOL_RESOLVED}..."
  ai_review::log  "────────────────────────────────────────────────────────────"

  export AI_REVIEW_AGAINST

  local review_output
  local invoke_rc=0
  review_output="$(ai_review::invoke_ai)" || invoke_rc=$?

  if (( JSON_ONLY == 1 )); then
    extract_review_json "${review_output}"
  else
    printf '%s\n' "${review_output}"
    ai_review::log "────────────────────────────────────────────────────────────"
  fi

  if (( invoke_rc != 0 )); then
    ai_review::err "AI CLI (${AI_REVIEW_TOOL_RESOLVED}) exited with code ${invoke_rc}."
    exit 1
  fi

  local result
  result="$(ai_review::parse_result "${review_output}")"

  # PR review uses APPROVE / COMMENT / REQUEST_CHANGES markers — different
  # vocabulary than the pre-commit hooks. The shared parser handles
  # PASS/WARN/BLOCK; we extend here for the PR markers.
  if grep -q '<<<AI_REVIEW_RESULT:APPROVE>>>' <<< "${review_output}"; then
    result="APPROVE"
  elif grep -q '<<<AI_REVIEW_RESULT:REQUEST_CHANGES>>>' <<< "${review_output}"; then
    result="REQUEST_CHANGES"
  elif grep -q '<<<AI_REVIEW_RESULT:COMMENT>>>' <<< "${review_output}"; then
    result="COMMENT"
  fi

  case "${result}" in
    APPROVE|COMMENT|REQUEST_CHANGES)
      ai_review::info "Review result: ${result}"
      ;;
    *)
      ai_review::err "Could not parse review result marker."
      ai_review::log "  Expected one of:"
      ai_review::log "      <<<AI_REVIEW_RESULT:APPROVE>>>"
      ai_review::log "      <<<AI_REVIEW_RESULT:COMMENT>>>"
      ai_review::log "      <<<AI_REVIEW_RESULT:REQUEST_CHANGES>>>"
      exit 1
      ;;
  esac

  # Post inline comments if requested.
  if (( POST_COMMENTS == 1 )); then
    if [[ -z "${AI_REVIEW_PR_NUMBER:-}" ]]; then
      ai_review::err "--post-comments requires a discoverable PR. Use --pr <number> or ensure 'gh pr view' resolves."
      exit 1
    fi
    local json_block
    json_block="$(extract_review_json "${review_output}")"
    if [[ -z "${json_block}" ]]; then
      ai_review::err "AI response did not contain a parseable JSON block."
      ai_review::log "  Expected fenced block bounded by:"
      ai_review::log "      <!-- AI_REVIEW_JSON_BEGIN -->"
      ai_review::log "      <!-- AI_REVIEW_JSON_END -->"
      exit 1
    fi
    post_review_to_github "${AI_REVIEW_PR_NUMBER}" "${json_block}"
  fi

  # --gate mode: exit non-zero on anything other than APPROVE.
  if (( GATE_MODE == 1 )) && [[ "${result}" != "APPROVE" ]]; then
    ai_review::err "--gate mode: review result is ${result}, exiting non-zero to fail the build."
    exit 1
  fi

  exit 0
}

pr_review::run
