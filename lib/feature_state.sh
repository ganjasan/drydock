#!/usr/bin/env bash
# Drydock plugin — feature flow state detector.
#
# `/dd:feature` is an end-to-end orchestrator that walks an idea from raw
# capture to draft PR across ten phases. It deliberately does NOT write a
# state file — phase position is derived purely from the artifact graph
# (raw entries, GitHub issues, OpenSpec change, branch, tasks.md, PR).
#
# This helper exposes a single function, `dd_feature_position`, that
# reports the current phase as one of:
#
#   none         no in-flow state — nothing started
#   idea         raw idea entry filed, no exploration cache yet
#   explored     exploration cached, no clarifying answers yet
#   clarified    clarifying answers captured, no issue/change yet
#   promoted     issue + OpenSpec change exist, no branch yet
#   started      branch (and optional worktree) exists, no architect draft
#   architected  <change>/design.draft.md present, design.md not yet promoted
#   designed     design.md applied, tasks.md generated with unchecked items
#   coded        all tasks checked, full-suite tests not yet run
#   tested       tests green (recent), no PR yet
#   pr           open PR for the active change
#
# The mapping from this enum to the phase numbers in the orchestrator skill
# (1..10) is in skills/feature-orchestrate/SKILL.md § "The phase table".
#
# Public API:
#   dd_feature_position           — print one of the enum values above
#   dd_feature_label <position>   — print a human label for a position
#
# Detection is best-effort and read-only. When a signal is ambiguous (e.g.
# multiple active changes), the function picks the earliest-phase active
# one so the orchestrator resumes safely rather than skipping ahead.

set -uo pipefail

# Source config.sh + paths.sh by relative location so this lib is usable
# independently of CLAUDE_PLUGIN_ROOT (consistent with hooks.sh).
if ! command -v dd_config_load >/dev/null 2>&1; then
  # shellcheck source=lib/config.sh
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi
if ! command -v dd_path >/dev/null 2>&1; then
  # shellcheck source=lib/paths.sh
  source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
fi

# ---------------------------------------------------------------------------
# Repo-root resolver (same logic as config.sh / hooks.sh)
# ---------------------------------------------------------------------------

_dd_feature_repo_root() {
  local d="$PWD"
  while [ "$d" != "/" ] && [ -n "$d" ]; do
    if [ -d "$d/.git" ] || [ -d "$d/.drydock" ]; then
      printf '%s\n' "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  printf '%s\n' "$PWD"
}

# ---------------------------------------------------------------------------
# Active OpenSpec change discovery
# ---------------------------------------------------------------------------
# Returns the slug of the first active change directory (status != done) or
# empty if none. "First" = lexicographic (typically date-prefixed slugs).
_dd_feature_active_change() {
  dd_config_load >/dev/null 2>&1 || true
  local changes_root
  changes_root="$(dd_path openspec_changes 2>/dev/null || true)"
  [ -d "$changes_root" ] || return 0

  local d slug status
  for d in "$changes_root"/*/; do
    [ -d "$d" ] || continue
    slug="$(basename "${d%/}")"
    case "$slug" in archive|.*) continue;; esac
    if [ -f "$d.openspec.yaml" ]; then
      status="$(awk -F: '/^status:/{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' "$d.openspec.yaml")"
      [ "$status" = "done" ] && continue
    fi
    printf '%s\n' "$slug"
    return 0
  done
}

# ---------------------------------------------------------------------------
# Tasks state for an active change
# ---------------------------------------------------------------------------
# Echoes "<done> <total>" (space-separated), or "0 0" if the change has no
# tasks.md yet.
_dd_feature_tasks_state() {
  local change_path="$1"
  local tasks="$change_path/tasks.md"
  [ -f "$tasks" ] || { printf '0 0\n'; return 0; }
  local done_count total_count
  done_count="$(grep -cE '^[[:space:]]*- \[x\]' "$tasks" 2>/dev/null || echo 0)"
  total_count="$(grep -cE '^[[:space:]]*- \[[x ]\]' "$tasks" 2>/dev/null || echo 0)"
  printf '%s %s\n' "$done_count" "$total_count"
}

# ---------------------------------------------------------------------------
# Branch + PR signals
# ---------------------------------------------------------------------------

_dd_feature_on_feature_branch() {
  local b
  b="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  case "$b" in
    feature/*) return 0 ;;
    *) return 1 ;;
  esac
}

_dd_feature_open_pr_for_branch() {
  local b
  b="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  [ -n "$b" ] || return 1
  command -v gh >/dev/null 2>&1 || return 1
  # `gh pr list` returns 0 with empty array when none — count rows.
  local count
  count="$(gh pr list --head "$b" --state open --json number 2>/dev/null \
    | jq -r 'length' 2>/dev/null || echo 0)"
  [ "$count" -gt 0 ]
}

# ---------------------------------------------------------------------------
# Exploration cache + clarifying answers (pre-artifact intermediate files)
# ---------------------------------------------------------------------------
# These are NOT phase-state. They are pre-artifact intermediates that the
# orchestrator caches between phases and gitignores. Their presence does
# not move the position forward — the position only advances when a
# permanent artifact is produced (issue, change, branch, etc.).
#
# The functions below are exposed for diagnostics (e.g. /dd:status), not
# for position determination.

_dd_feature_exploration_cache_path() {
  local repo_root
  repo_root="$(_dd_feature_repo_root)"
  local change_slug change_path
  change_slug="$(_dd_feature_active_change)"
  if [ -n "$change_slug" ]; then
    change_path="$(dd_path openspec_changes 2>/dev/null)/${change_slug}"
    if [ -f "$change_path/.exploration.md" ]; then
      printf '%s\n' "$change_path/.exploration.md"
      return 0
    fi
  fi
  if [ -f "$repo_root/.feature-exploration.md" ]; then
    printf '%s\n' "$repo_root/.feature-exploration.md"
    return 0
  fi
  return 1
}

_dd_feature_clarifying_answers_path() {
  local repo_root change_slug change_path
  repo_root="$(_dd_feature_repo_root)"
  change_slug="$(_dd_feature_active_change)"
  if [ -n "$change_slug" ]; then
    change_path="$(dd_path openspec_changes 2>/dev/null)/${change_slug}"
    if [ -f "$change_path/.feature-clarifying-answers.md" ]; then
      printf '%s\n' "$change_path/.feature-clarifying-answers.md"
      return 0
    fi
  fi
  if [ -f "$repo_root/.feature-clarifying-answers.md" ]; then
    printf '%s\n' "$repo_root/.feature-clarifying-answers.md"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Public: dd_feature_position
# ---------------------------------------------------------------------------
# Returns the current phase as one of the enum values listed at the top of
# this file. Determines the position from the artifact graph alone.

dd_feature_position() {
  local change_slug change_path tasks_state done_count total_count

  change_slug="$(_dd_feature_active_change)"
  if [ -z "$change_slug" ]; then
    # No active change. Still might be on phases 1..3 (idea/explore/clarify).
    if _dd_feature_clarifying_answers_path >/dev/null 2>&1; then
      printf 'clarified\n'; return 0
    fi
    if _dd_feature_exploration_cache_path >/dev/null 2>&1; then
      printf 'explored\n'; return 0
    fi
    # No way to tell from artifacts whether an idea was filed for *this* flow
    # specifically (raw entries are cheap and many). Return 'none'; the
    # orchestrator's resume mode will start from phase 1 in that case.
    printf 'none\n'; return 0
  fi

  change_path="$(dd_path openspec_changes 2>/dev/null)/${change_slug}"

  # Active change exists. Check progressively later signals.
  if _dd_feature_open_pr_for_branch; then
    printf 'pr\n'; return 0
  fi

  tasks_state="$(_dd_feature_tasks_state "$change_path")"
  read -r done_count total_count <<<"$tasks_state"

  # Tasks all checked + a recent test marker → tested. We don't track a
  # test-marker file (tests are external), so collapse 'tested' into 'coded'
  # for the purposes of position; the orchestrator on resume runs tests and
  # then proceeds. 'tested' is reachable only after an explicit pause-after-
  # test stop, which is outside this helper's scope.
  if [ "$total_count" -gt 0 ] && [ "$done_count" -eq "$total_count" ]; then
    printf 'coded\n'; return 0
  fi

  # tasks.md exists with unchecked items → designed (ready to implement).
  if [ "$total_count" -gt 0 ]; then
    printf 'designed\n'; return 0
  fi

  # design.md applied (no draft remaining)?
  if [ -f "$change_path/design.md" ] && [ ! -f "$change_path/design.draft.md" ]; then
    # design.md exists but no tasks → still designing. Stay on 'designed'
    # at zero-tasks; phase 7 (build:design) will fill them in.
    if [ -s "$change_path/design.md" ]; then
      printf 'designed\n'; return 0
    fi
  fi

  # Architect draft exists, design.md not yet promoted.
  if [ -f "$change_path/design.draft.md" ]; then
    printf 'architected\n'; return 0
  fi

  # Branch exists for the linked issue?
  if _dd_feature_on_feature_branch; then
    printf 'started\n'; return 0
  fi

  # Change scaffolded but no branch yet.
  printf 'promoted\n'
}

# ---------------------------------------------------------------------------
# Public: dd_feature_label
# ---------------------------------------------------------------------------
# Maps a position enum value to a human-readable phase label.

dd_feature_label() {
  case "$1" in
    none)        printf 'no flow active\n' ;;
    idea)        printf 'phase 1 — idea captured\n' ;;
    explored)    printf 'phase 2 — code explored\n' ;;
    clarified)   printf 'phase 3 — clarifying answers captured\n' ;;
    promoted)    printf 'phase 4 — issue + change scaffolded\n' ;;
    started)     printf 'phase 5 — branch + worktree created\n' ;;
    architected) printf 'phase 6 — architect draft ready for review\n' ;;
    designed)    printf 'phase 7 — design.md + tasks.md ready, implementation pending\n' ;;
    coded)       printf 'phase 8 — implementation done, tests pending\n' ;;
    tested)      printf 'phase 9 — tests green, PR pending\n' ;;
    pr)          printf 'phase 10 — draft PR open\n' ;;
    *)           printf 'unknown position: %s\n' "$1" ;;
  esac
}
