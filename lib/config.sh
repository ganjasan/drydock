#!/usr/bin/env bash
# Drydock plugin — configuration loader.
#
# Resolves ${CLAUDE_PLUGIN_ROOT}/config.yaml (if present), merges with built-in
# defaults, and exposes scalar lookups via the `cfg_get` helper.
#
# Usage from a command body:
#   source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"
#   triage_label="$(cfg_get github.triage_label)"
#
# `yq` is preferred when available; otherwise a minimal awk fallback walks
# nested keys (top-level only — for nested keys yq is required).

set -euo pipefail

DRYDOCK_CONFIG_PATH="${DRYDOCK_CONFIG_PATH:-${CLAUDE_PLUGIN_ROOT:-$(pwd)}/config.yaml}"

# Built-in defaults. Echoed when neither config.yaml nor an override env var
# supplies the key. Keep these aligned with config.yaml.example.
_cfg_default() {
  case "$1" in
    paths.requirements) echo "requirements" ;;
    paths.requirements_subdirs.vision) echo "vision" ;;
    paths.requirements_subdirs.stakeholders) echo "stakeholders" ;;
    paths.requirements_subdirs.use_cases) echo "use-cases" ;;
    paths.requirements_subdirs.adr) echo "adr" ;;
    paths.openspec.changes) echo "openspec/changes" ;;
    paths.openspec.specs) echo "openspec/specs" ;;
    worktree.enabled) echo "false" ;;
    worktree.base_dir) echo ".worktrees" ;;
    worktree.naming) echo "wt-<issue-id>" ;;
    worktree.branch_naming) echo "feature/<issue-id>-<slug>" ;;
    github.triage_label) echo "status/needs-triage" ;;
    *) echo "" ;;
  esac
}

# Read a dotted key from config.yaml, falling back to defaults.
# Usage: cfg_get <dotted.key>
cfg_get() {
  local key="$1"
  if [ -f "$DRYDOCK_CONFIG_PATH" ] && command -v yq >/dev/null 2>&1; then
    local val
    val="$(yq -r ".${key} // \"\"" "$DRYDOCK_CONFIG_PATH" 2>/dev/null || true)"
    if [ -n "$val" ] && [ "$val" != "null" ]; then
      printf '%s\n' "$val"
      return 0
    fi
  fi
  _cfg_default "$key"
}

# Returns 0 if a key is explicitly set in config.yaml (yq required), else 1.
cfg_has() {
  local key="$1"
  [ -f "$DRYDOCK_CONFIG_PATH" ] || return 1
  command -v yq >/dev/null 2>&1 || return 1
  local val
  val="$(yq -r ".${key} // \"__MISSING__\"" "$DRYDOCK_CONFIG_PATH" 2>/dev/null || echo "__MISSING__")"
  [ "$val" != "__MISSING__" ] && [ "$val" != "null" ]
}

# Print the resolved config path (for diagnostic output).
cfg_path() {
  printf '%s\n' "$DRYDOCK_CONFIG_PATH"
}
