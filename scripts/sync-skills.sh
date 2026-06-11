#!/usr/bin/env bash
# scripts/sync-skills.sh
#
# Synchronize SKILL.md files from the tool-neutral canonical location
# (.skills/) to the tool-specific locations that each AI CLI looks at.
#
# Canonical (source of truth):
#   .skills/<skill>/SKILL.md
#
# Tool-specific destinations (only created/updated for tools you use):
#   claude   → .claude/skills/<skill>/SKILL.md
#   codex    → .codex/skills/<skill>/SKILL.md
#   copilot  → .github/copilot/skills/<skill>/SKILL.md
#
# By default, this script only writes to the destination(s) matching the
# developer's current AI_REVIEW_TOOL setting. A developer who only uses Codex
# will never see .claude/ or .github/copilot/skills/ directories materialize
# in their checkout.
#
# Behavior is controlled by AI_REVIEW_SYNC_TARGETS, falling back to
# AI_REVIEW_TOOL:
#
#   AI_REVIEW_SYNC_TARGETS=claude              # only sync claude
#   AI_REVIEW_SYNC_TARGETS=codex,copilot       # sync two
#   AI_REVIEW_SYNC_TARGETS=all                 # sync all three (maintainer use)
#
# Usage:
#   scripts/sync-skills.sh                    # sync to the resolved targets
#   scripts/sync-skills.sh --check            # exit non-zero if a sync is
#                                             # needed but hasn't been run;
#                                             # only checks resolved targets
#   scripts/sync-skills.sh --dry-run          # alias for --check (matches the
#                                             # naming used by every other
#                                             # dispatcher in this project)
#   scripts/sync-skills.sh --targets all      # one-shot override of targets
#   scripts/sync-skills.sh --targets claude,codex --check

set -euo pipefail

# ── Resolve repo root ──────────────────────────────────────────────────────
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "${REPO_ROOT}"

# ── Skills to sync ─────────────────────────────────────────────────────────
SKILLS=(
  "code-security"
  "iac-compliance"
  "pr-review"
  "codebase-audit"
  "finding-adjudication"
)

# ── Tool-to-destination mapping ────────────────────────────────────────────
# Adding a new AI tool means adding one line here.
tool_dest_root() {
  case "$1" in
    claude)  echo ".claude/skills" ;;
    codex)   echo ".codex/skills" ;;
    copilot) echo ".github/copilot/skills" ;;
    *)       return 1 ;;
  esac
}

ALL_TOOLS=("claude" "codex" "copilot")

# ── Parse args ─────────────────────────────────────────────────────────────
CHECK_ONLY=0
TARGETS_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check|-n|--dry-run)
      # --dry-run / -n is an alias for --check, matching the naming used by
      # every other dispatcher in this project (.skills/*/scripts/*.sh).
      # Behavior is identical: report drift, exit non-zero if any, write
      # nothing.
      CHECK_ONLY=1
      shift
      ;;
    --targets)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --targets requires a value (comma-separated list, or 'all')" >&2
        exit 2
      fi
      TARGETS_ARG="$2"
      shift 2
      ;;
    --targets=*)
      TARGETS_ARG="${1#*=}"
      shift
      ;;
    -h|--help)
      sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# ── Resolve sync targets ───────────────────────────────────────────────────
# Precedence: --targets flag > AI_REVIEW_SYNC_TARGETS env > AI_REVIEW_TOOL env
RESOLVED_TARGETS_RAW=""
if [[ -n "${TARGETS_ARG}" ]]; then
  RESOLVED_TARGETS_RAW="${TARGETS_ARG}"
elif [[ -n "${AI_REVIEW_SYNC_TARGETS:-}" ]]; then
  RESOLVED_TARGETS_RAW="${AI_REVIEW_SYNC_TARGETS}"
elif [[ -n "${AI_REVIEW_TOOL:-}" ]]; then
  RESOLVED_TARGETS_RAW="${AI_REVIEW_TOOL}"
else
  echo "ERROR: cannot resolve sync targets." >&2
  echo "       Set AI_REVIEW_TOOL (your chosen AI assistant) or pass --targets." >&2
  echo "       Examples:" >&2
  echo "           export AI_REVIEW_TOOL=claude   # then re-run" >&2
  echo "           scripts/sync-skills.sh --targets claude" >&2
  echo "           scripts/sync-skills.sh --targets all" >&2
  exit 2
fi

# Lower-case and expand "all".
RESOLVED_TARGETS_RAW="$(printf '%s' "${RESOLVED_TARGETS_RAW}" | tr '[:upper:]' '[:lower:]')"
if [[ "${RESOLVED_TARGETS_RAW}" == "all" ]]; then
  TARGETS=("${ALL_TOOLS[@]}")
else
  IFS=',' read -ra TARGETS <<< "${RESOLVED_TARGETS_RAW}"
fi

# Validate each target.
for tool in "${TARGETS[@]}"; do
  if ! tool_dest_root "${tool}" >/dev/null 2>&1; then
    echo "ERROR: unknown sync target: ${tool}" >&2
    echo "       Valid targets: claude | codex | copilot | all" >&2
    exit 2
  fi
done

# ── Sync logic ─────────────────────────────────────────────────────────────
DRIFT=0
SYNCED=0
ALREADY_OK=0

for skill in "${SKILLS[@]}"; do
  src=".skills/${skill}/SKILL.md"
  if [[ ! -f "${src}" ]]; then
    echo "ERROR: canonical skill file not found: ${src}" >&2
    echo "       The .skills/ directory is the source of truth and must exist." >&2
    exit 1
  fi

  for tool in "${TARGETS[@]}"; do
    dest_root="$(tool_dest_root "${tool}")"
    dest="${dest_root}/${skill}/SKILL.md"

    if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
      ALREADY_OK=$((ALREADY_OK + 1))
      continue
    fi

    if (( CHECK_ONLY == 1 )); then
      if [[ -f "${dest}" ]]; then
        echo "OUT OF SYNC: ${dest}" >&2
        echo "             differs from ${src}" >&2
      else
        echo "MISSING:     ${dest}" >&2
        echo "             expected derived copy of ${src}" >&2
      fi
      DRIFT=1
    else
      mkdir -p "$(dirname "${dest}")"
      cp "${src}" "${dest}"
      echo "synced: ${src} → ${dest}"
      SYNCED=$((SYNCED + 1))
    fi
  done
done

# ── Report ─────────────────────────────────────────────────────────────────
if (( CHECK_ONLY == 1 )); then
  if (( DRIFT == 1 )); then
    echo "" >&2
    echo "Skill files are out of sync for resolved targets: ${TARGETS[*]}" >&2
    echo "Run:" >&2
    echo "    scripts/sync-skills.sh" >&2
    echo "and stage the updated files before committing." >&2
    exit 1
  fi
  echo "All skill files are in sync for targets: ${TARGETS[*]}"
else
  if (( SYNCED == 0 )); then
    echo "All skill files were already in sync for targets: ${TARGETS[*]} (nothing to do)."
  else
    echo ""
    echo "Synced ${SYNCED} file(s) to targets: ${TARGETS[*]}"
    echo "Remember to stage the updated files before committing."
  fi
fi
