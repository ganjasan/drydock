#!/usr/bin/env bash
# Drydock plugin — area_to_repo resolution.
#
# Resolves an issue's Area-field value to a target repo path per the documented
# edge cases. Produces fail-loud diagnostics with copy-pasteable mappings the
# user can drop into <repo>/.drydock/config.yaml.
#
# Public API:
#   dd_resolve_area <area>
#     stdout: absolute path to target repo (or empty for the current repo)
#     return: 0 on success; non-zero with diagnostic on missing-mapping error
#
#   Edge cases:
#     1. area_to_repo is unset entirely         → echo current repo, return 0
#     2. area_to_repo set, area not in map      → diagnostic, return 1
#     3. value "."                              → echo current repo, return 0
#     4. absolute path (starts with /)          → echo path, return 0
#     5. relative path                          → resolved against parent dir
#                                                 of the current repo, return 0

set -uo pipefail

if ! command -v dd_config_load >/dev/null 2>&1; then
  # shellcheck source=lib/config.sh
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

_dd_area_repo_root() {
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

dd_resolve_area() {
  local area="$1"
  dd_config_load >/dev/null

  local repo_root parent
  repo_root="$(_dd_area_repo_root)"
  parent="$(dirname "$repo_root")"

  # Edge case 1: area_to_repo unset entirely → current repo.
  if ! cfg_has area_to_repo; then
    printf '%s\n' "$repo_root"
    return 0
  fi

  local value
  value="$(cfg_get "area_to_repo.${area}")"

  # Edge case 2: area_to_repo set but the requested area not in map → fail loud.
  if [ -z "$value" ]; then
    cat >&2 <<EOF

ERROR: Area '${area}' has no entry in area_to_repo.

Add a mapping to <repo>/.drydock/config.yaml:

  area_to_repo:
    ${area}: <relative-or-absolute-repo-path>

Or set the issue's Area field to a known value. Known mappings:
EOF
    cfg_keys_of area_to_repo | while read -r k; do
      [ -n "$k" ] && printf '  - %s → %s\n' "$k" "$(cfg_get "area_to_repo.${k}")" >&2
    done
    return 1
  fi

  case "$value" in
    .)
      # Edge case 3: "." → current repo.
      printf '%s\n' "$repo_root"
      ;;
    /*)
      # Edge case 4: absolute path.
      printf '%s\n' "$value"
      ;;
    *)
      # Edge case 5: relative → resolve against parent of current repo.
      printf '%s/%s\n' "$parent" "$value"
      ;;
  esac
  return 0
}
