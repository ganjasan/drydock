#!/usr/bin/env bash
# Drydock plugin — lifecycle hook dispatcher.
#
# Hooks live at <repo>/.drydock/hooks/<event>.sh. They receive a JSON payload
# on stdin and signal pass/fail via exit code. Discovery is by file presence:
# missing files are silently skipped; non-executable files emit a one-line
# warning and are skipped.
#
# Exit-code semantics by category:
#   pre-*         non-zero aborts the originating Drydock operation.
#   post-*        non-zero is reported as a warning; the operation keeps state.
#   session-start non-zero is reported; Claude Code session continues.
#
# Public entrypoints:
#   dd_hook_invoke <event> [<extra-payload-json>]
#     Invokes <repo>/.drydock/hooks/<event>.sh if present and executable,
#     building the payload from event metadata + the optional extra fields.
#     Returns 0 on success, the hook's exit code on pre-* failure, or 0 on
#     post-*/session-start "soft" failures (warning only).

set -euo pipefail

# Source config.sh from the same lib/ directory as this file — we need the
# materialized merged config path and DRYDOCK_CONFIG_PATH to embed in the
# payload. Use $BASH_SOURCE so this works independently of CLAUDE_PLUGIN_ROOT
# (which controls only the plugin-root config layer, not the lib lookup).
if ! command -v dd_config_load >/dev/null 2>&1; then
  # shellcheck source=lib/config.sh
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

# ---------------------------------------------------------------------------
# Hook category helpers
# ---------------------------------------------------------------------------

# Categorize a hook event name. Echoes one of: pre, post, session-start, other.
_dd_hook_category() {
  case "$1" in
    pre-*)         echo "pre" ;;
    post-*)        echo "post" ;;
    session-start) echo "session-start" ;;
    *)             echo "other" ;;
  esac
}

# Locate the script for a given event: <repo>/.drydock/hooks/<event>.sh.
_dd_hook_script_path() {
  local event="$1"
  local repo_root
  repo_root="$(
    d="$PWD"
    while [ "$d" != "/" ] && [ -n "$d" ]; do
      if [ -d "$d/.git" ] || [ -d "$d/.drydock" ]; then echo "$d"; exit 0; fi
      d="$(dirname "$d")"
    done
    echo "$PWD"
  )"
  printf '%s/.drydock/hooks/%s.sh\n' "$repo_root" "$event"
}

# ---------------------------------------------------------------------------
# Payload construction
# ---------------------------------------------------------------------------

# Build the JSON payload for a hook invocation.
# Required fields in the merged JSON:
#   event       — the hook event name
#   repo_path   — absolute path to the repo root
#   config_path — absolute path to the materialized merged config (DRYDOCK_CONFIG_PATH)
# Plus any keys provided via the optional extra-payload-json argument
# (must be a JSON object string; merged at top level, extras win).
_dd_hook_build_payload() {
  local event="$1"
  local extra="${2:-{\}}"
  dd_config_load >/dev/null

  local repo_root
  repo_root="$(
    d="$PWD"
    while [ "$d" != "/" ] && [ -n "$d" ]; do
      if [ -d "$d/.git" ] || [ -d "$d/.drydock" ]; then echo "$d"; exit 0; fi
      d="$(dirname "$d")"
    done
    echo "$PWD"
  )"

  jq -cn \
    --arg event "$event" \
    --arg repo_path "$repo_root" \
    --arg config_path "${DRYDOCK_CONFIG_PATH:-}" \
    --argjson extra "$extra" \
    '{event: $event, repo_path: $repo_path, config_path: $config_path} * $extra'
}

# ---------------------------------------------------------------------------
# Public: dd_hook_invoke
# ---------------------------------------------------------------------------

# Invoke the hook for a lifecycle event.
# Usage:
#   dd_hook_invoke pre-pr  '{"branch":"feature/x", "commits":["sha1","sha2"]}'
#   dd_hook_invoke post-archive '{"change_slug":"my-change"}'
#
# Returns:
#   0       hook absent, hook ran successfully, OR post-/session-start hook
#           failed (warning only — caller continues).
#   non-0   pre-* hook failed — caller MUST abort.
dd_hook_invoke() {
  local event="$1"
  local extra="${2:-{\}}"
  local script payload category exit_code

  script="$(_dd_hook_script_path "$event")"
  category="$(_dd_hook_category "$event")"

  if [ ! -e "$script" ]; then
    return 0   # silently skip missing hook
  fi

  if [ ! -x "$script" ]; then
    echo "[drydock] WARN: hook ${event} found at ${script} but is not executable; skipping" >&2
    return 0
  fi

  payload="$(_dd_hook_build_payload "$event" "$extra")"

  # Run the hook with strict-mode temporarily disabled so a non-zero exit
  # from the hook does not abort our shell — we want to inspect the code
  # and dispatch on it.
  set +e
  printf '%s' "$payload" | "$script"
  exit_code=$?

  case "$category" in
    pre)
      if [ "$exit_code" -ne 0 ]; then
        echo "[drydock] ERROR: hook ${event} (${script}) exited ${exit_code} — aborting" >&2
        return "$exit_code"
      fi
      ;;
    post|session-start|other)
      if [ "$exit_code" -ne 0 ]; then
        echo "[drydock] WARN: hook ${event} (${script}) exited ${exit_code} — operation continues" >&2
      fi
      ;;
  esac
  return 0
}
