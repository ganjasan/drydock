#!/usr/bin/env bash
# Drydock plugin — configuration loader (v0.2: three-layer merge).
#
# Layers, later wins at the leaf-key level:
#   1. ${CLAUDE_PLUGIN_ROOT}/config.yaml     plugin defaults shipped with Drydock
#   2. ~/.drydock/config.yaml                user-level overrides (optional)
#   3. <repo>/.drydock/config.yaml           per-repo, checked-in (wins)
#
# Map values merge key-by-key. List values replace wholesale.
#
# The merged result is materialized to a per-invocation JSON tempfile pointed
# at by $DRYDOCK_CONFIG_PATH. Hook scripts receive the same path in their
# stdin payload (see lib/hooks.sh).
#
# Usage from a command body:
#   source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"
#   triage_label="$(cfg_get github.triage_label)"
#
# Requires: yq (YAML→JSON), jq (deep merge + lookups). Both are probed at
# load time and produce a clear install message if missing.

set -euo pipefail

# ---------------------------------------------------------------------------
# Layer paths
# ---------------------------------------------------------------------------

_dd_plugin_config_path()  { printf '%s\n' "${CLAUDE_PLUGIN_ROOT:-}/config.yaml"; }
_dd_user_config_path()    { printf '%s\n' "${HOME}/.drydock/config.yaml"; }

# Walk up from $PWD to find the repo root: first directory containing .git or
# .drydock. Fall back to $PWD if neither is found (a non-repo invocation —
# Drydock still works, just with no per-repo overlay).
_dd_repo_root() {
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

_dd_repo_config_path() {
  printf '%s/.drydock/config.yaml\n' "$(_dd_repo_root)"
}

# ---------------------------------------------------------------------------
# Tooling probes
# ---------------------------------------------------------------------------

_dd_require_yq() {
  command -v yq >/dev/null 2>&1 && return 0
  cat >&2 <<'EOF'
ERROR: yq is required for Drydock configuration loading but is not installed.

Install:
  macOS:  brew install yq
  Linux:  sudo apt install yq            # or download a static binary from
                                         # https://github.com/mikefarah/yq/releases

Verify:  yq --version
EOF
  return 1
}

_dd_require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  cat >&2 <<'EOF'
ERROR: jq is required for Drydock configuration loading but is not installed.

Install:
  macOS:  brew install jq
  Linux:  sudo apt install jq

Verify:  jq --version
EOF
  return 1
}

# ---------------------------------------------------------------------------
# Alternate-location guard
# ---------------------------------------------------------------------------
# Drydock loads per-repo config from <repo>/.drydock/config.yaml only.
# If a user accidentally puts config at a sibling location, fail loudly so
# they don't silently rely on a file Drydock will never read.
_dd_reject_alternates() {
  local repo_root="$1"
  local alt
  for alt in "$repo_root/drydock.yaml" "$repo_root/.drydock.yaml"; do
    if [ -f "$alt" ]; then
      cat >&2 <<EOF
ERROR: configuration found at a non-supported location: $alt

Drydock reads per-repo configuration from <repo>/.drydock/config.yaml only.
Move the file:
  mkdir -p "$repo_root/.drydock"
  mv "$alt" "$repo_root/.drydock/config.yaml"
EOF
      return 1
    fi
  done
}

# ---------------------------------------------------------------------------
# Merge primitives
# ---------------------------------------------------------------------------

# YAML → JSON. Empty / missing file → "{}".
_dd_yaml_to_json() {
  local f="$1"
  if [ -f "$f" ] && [ -s "$f" ]; then
    yq -o=json '.' "$f" 2>/dev/null || printf '%s\n' '{}'
  else
    printf '%s\n' '{}'
  fi
}

# Deep-merge two JSON documents.
#   - Both objects → merge key-by-key, recursing.
#   - Otherwise (list, scalar, type mismatch) → second argument wins.
# Usage: _dd_merge_json <base.json> <override.json>  (writes merged JSON to stdout)
_dd_merge_json() {
  local base="$1" override="$2"
  jq -n --slurpfile a "$base" --slurpfile b "$override" '
    def merge(a; b):
      if (a | type) == "object" and (b | type) == "object"
      then reduce ((a | keys_unsorted) + (b | keys_unsorted) | unique)[] as $k
           ({}; .[$k] = (
             if   (a | has($k)) and (b | has($k)) then merge(a[$k]; b[$k])
             elif (b | has($k))                    then b[$k]
             else                                       a[$k]
             end))
      else b
      end;
    merge($a[0]; $b[0])
  '
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

_dd_cleanup_config() {
  if [ -n "${_DD_CONFIG_TMPDIR:-}" ] && [ -d "${_DD_CONFIG_TMPDIR}" ]; then
    rm -rf "${_DD_CONFIG_TMPDIR}"
  fi
}

# Register cleanup on EXIT, composing with any pre-existing EXIT trap so we
# don't clobber the caller's own cleanup logic.
_dd_register_cleanup() {
  local prior
  prior="$(trap -p EXIT 2>/dev/null | sed -E "s/^trap -- '(.*)' EXIT\$/\\1/")"
  if [ -z "$prior" ]; then
    trap '_dd_cleanup_config' EXIT
  else
    trap "${prior}; _dd_cleanup_config" EXIT
  fi
}

# ---------------------------------------------------------------------------
# Public: load merged config
# ---------------------------------------------------------------------------

# Materialize the merged config to a temp JSON file and export
# DRYDOCK_CONFIG_PATH. Idempotent — repeated calls are a no-op.
dd_config_load() {
  if [ -n "${DRYDOCK_CONFIG_PATH:-}" ] && [ -f "${DRYDOCK_CONFIG_PATH:-}" ] \
     && [ -n "${_DD_CONFIG_TMPDIR:-}" ]; then
    return 0
  fi

  _dd_require_yq || return 1
  _dd_require_jq || return 1

  local repo_root; repo_root="$(_dd_repo_root)"
  _dd_reject_alternates "$repo_root" || return 1

  local plugin_cfg user_cfg repo_cfg
  plugin_cfg="$(_dd_plugin_config_path)"
  user_cfg="$(_dd_user_config_path)"
  repo_cfg="$(_dd_repo_config_path)"

  local tmpdir; tmpdir="$(mktemp -d -t drydock-config-XXXXXX)"
  local out="${tmpdir}/config.json"
  local plugin_json="${tmpdir}/plugin.json"
  local user_json="${tmpdir}/user.json"
  local repo_json="${tmpdir}/repo.json"
  local mid_json="${tmpdir}/mid.json"

  _dd_yaml_to_json "$plugin_cfg" > "$plugin_json"
  _dd_yaml_to_json "$user_cfg"   > "$user_json"
  _dd_yaml_to_json "$repo_cfg"   > "$repo_json"

  _dd_merge_json "$plugin_json" "$user_json" > "$mid_json"
  _dd_merge_json "$mid_json"    "$repo_json" > "$out"

  export DRYDOCK_CONFIG_PATH="$out"
  export _DD_CONFIG_TMPDIR="$tmpdir"
  _dd_register_cleanup
}

# ---------------------------------------------------------------------------
# Public: lookups
# ---------------------------------------------------------------------------

# Built-in defaults — returned by cfg_get when a key is absent from the
# merged config. Keep aligned with config.yaml.example and templates.
_cfg_default() {
  case "$1" in
    paths.requirements)                       echo "requirements" ;;
    paths.requirements_subdirs.vision)        echo "vision" ;;
    paths.requirements_subdirs.stakeholders)  echo "stakeholders" ;;
    paths.requirements_subdirs.use_cases)     echo "use-cases" ;;
    paths.requirements_subdirs.adr)           echo "adr" ;;
    paths.openspec.changes)                   echo "openspec/changes" ;;
    paths.openspec.specs)                     echo "openspec/specs" ;;
    paths.raw_root)                           echo "raw" ;;
    paths.raw_subdirs.incoming)               echo "_incoming" ;;
    paths.raw_subdirs.meetings)               echo "meetings" ;;
    paths.raw_subdirs.feedback)               echo "feedback" ;;
    paths.raw_subdirs.ideas)                  echo "ideas" ;;
    paths.raw_subdirs.competitors)            echo "competitors" ;;
    paths.raw_subdirs.client_boards)          echo "client-boards" ;;
    worktree.enabled)                         echo "false" ;;
    worktree.base_dir)                        echo ".worktrees" ;;
    worktree.naming)                          echo "wt-<issue-id>" ;;
    worktree.branch_naming)                   echo "feature/<issue-id>-<slug>" ;;
    github.triage_label)                      echo "status/needs-triage" ;;
    release.dry_run_default)                  echo "false" ;;
    *)                                        echo "" ;;
  esac
}

# Read a dotted scalar key from the merged config; falls back to built-in default.
# Usage: cfg_get <dotted.key>
cfg_get() {
  local key="$1"
  dd_config_load || return 1
  local val
  val="$(jq -r ".${key} // empty" "$DRYDOCK_CONFIG_PATH" 2>/dev/null || true)"
  if [ -n "$val" ] && [ "$val" != "null" ]; then
    printf '%s\n' "$val"
    return 0
  fi
  _cfg_default "$key"
}

# Returns 0 if a key is explicitly set in the merged config, else 1.
cfg_has() {
  local key="$1"
  dd_config_load || return 1
  local val
  val="$(jq -r ".${key} // \"__MISSING__\"" "$DRYDOCK_CONFIG_PATH" 2>/dev/null || echo "__MISSING__")"
  [ "$val" != "__MISSING__" ] && [ "$val" != "null" ]
}

# Read an array-valued key as newline-separated entries. Prints nothing for
# missing or non-array keys.
# Usage: cfg_array_get <dotted.key>
cfg_array_get() {
  local key="$1"
  dd_config_load || return 1
  jq -r ".${key} // [] | if type == \"array\" then .[] else empty end" \
     "$DRYDOCK_CONFIG_PATH" 2>/dev/null || true
}

# Read keys of an object-valued key as newline-separated names. Prints nothing
# for missing or non-object keys.
# Usage: cfg_keys_of <dotted.key>
cfg_keys_of() {
  local key="$1"
  dd_config_load || return 1
  jq -r ".${key} // {} | if type == \"object\" then keys_unsorted[] else empty end" \
     "$DRYDOCK_CONFIG_PATH" 2>/dev/null || true
}

# Print the materialized merged config path. Used by hooks and diagnostics.
cfg_path() {
  dd_config_load || return 1
  printf '%s\n' "$DRYDOCK_CONFIG_PATH"
}
