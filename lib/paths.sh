#!/usr/bin/env bash
# Drydock plugin — path resolution helper.
#
# Single resolver for every path-shaped value commands need: requirements
# subdirs, OpenSpec layout, raw inbox, worktree, branch naming. Reads merged
# config via lib/config.sh; commands MUST NOT reach for paths.* keys directly.
#
# Public API:
#   dd_path requirements                                → <repo>/<paths.requirements>/
#   dd_path requirements_subdir <vision|stakeholders|use_cases|adr>
#   dd_path openspec_changes                            → <repo>/<paths.openspec.changes>/
#   dd_path openspec_specs                              → <repo>/<paths.openspec.specs>/
#   dd_path raw_root                                    → <repo>/<paths.raw_root>/
#   dd_path raw_subdir <incoming|meetings|feedback|ideas|competitors|client_boards>
#   dd_path worktree_base                               → resolved worktree.base_dir
#   dd_branch_name <issue-id> <slug>                    → expanded worktree.branch_naming
#   dd_worktree_dir <issue-id> <slug>                   → <worktree_base>/<expanded worktree.naming>
#
# All paths returned absolute (resolved against the repo root). Token
# substitution accepts <issue-id> and <slug>; unknown tokens cause an error.

set -uo pipefail

# Source config.sh by relative location so this lib is usable independently
# of CLAUDE_PLUGIN_ROOT (consistent with hooks.sh).
if ! command -v dd_config_load >/dev/null 2>&1; then
  # shellcheck source=lib/config.sh
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

# Resolve the repo root: nearest ancestor of $PWD containing .git or .drydock,
# else $PWD.
_dd_paths_repo_root() {
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

# Join repo root and a relative path; strip trailing slashes from the input
# and ensure exactly one separator.
_dd_paths_join() {
  local root="$1" rel="$2"
  rel="${rel%/}"
  printf '%s/%s\n' "${root%/}" "$rel"
}

# Public: dd_path <subkind> [<arg>]
dd_path() {
  local kind="$1"
  local arg="${2:-}"
  dd_config_load >/dev/null

  local repo_root rel
  repo_root="$(_dd_paths_repo_root)"

  case "$kind" in
    requirements)
      rel="$(cfg_get paths.requirements)"
      _dd_paths_join "$repo_root" "$rel"
      ;;
    requirements_subdir)
      [ -n "$arg" ] || { echo "dd_path requirements_subdir requires a name" >&2; return 2; }
      local sub
      sub="$(cfg_get "paths.requirements_subdirs.${arg}")"
      [ -n "$sub" ] || { echo "no path for requirements_subdirs.${arg}" >&2; return 2; }
      _dd_paths_join "$repo_root" "$(cfg_get paths.requirements)/$sub"
      ;;
    openspec_changes)
      _dd_paths_join "$repo_root" "$(cfg_get paths.openspec.changes)"
      ;;
    openspec_specs)
      _dd_paths_join "$repo_root" "$(cfg_get paths.openspec.specs)"
      ;;
    raw_root)
      _dd_paths_join "$repo_root" "$(cfg_get paths.raw_root)"
      ;;
    raw_subdir)
      [ -n "$arg" ] || { echo "dd_path raw_subdir requires a name" >&2; return 2; }
      local rsub
      rsub="$(cfg_get "paths.raw_subdirs.${arg}")"
      [ -n "$rsub" ] || { echo "no path for raw_subdirs.${arg}" >&2; return 2; }
      _dd_paths_join "$repo_root" "$(cfg_get paths.raw_root)/$rsub"
      ;;
    worktree_base)
      local base
      base="$(cfg_get worktree.base_dir)"
      # Absolute paths used verbatim; relative paths joined to repo root.
      case "$base" in
        /*) printf '%s\n' "$base" ;;
        *)  _dd_paths_join "$repo_root" "$base" ;;
      esac
      ;;
    *)
      echo "dd_path: unknown subkind '$kind' (expected: requirements, requirements_subdir, openspec_changes, openspec_specs, raw_root, raw_subdir, worktree_base)" >&2
      return 2
      ;;
  esac
}

# Token substitution helper. Accepts only <issue-id> and <slug>; unknown
# tokens (anything matching /<[^>]+>/) trigger a clear error.
_dd_paths_subst_tokens() {
  local template="$1" issue="$2" slug="$3"
  local out="$template"
  out="${out//<issue-id>/$issue}"
  out="${out//<slug>/$slug}"
  # Detect unknown <...> remnants.
  case "$out" in
    *"<"*">"*)
      local rest="${out#*<}"
      local tok="${rest%%>*}"
      echo "dd_paths: unknown token '<${tok}>' in template '${template}'; supported: <issue-id>, <slug>" >&2
      return 2
      ;;
  esac
  printf '%s\n' "$out"
}

# Public: dd_branch_name <issue-id> <slug>
dd_branch_name() {
  local issue="$1" slug="$2"
  dd_config_load >/dev/null
  _dd_paths_subst_tokens "$(cfg_get worktree.branch_naming)" "$issue" "$slug"
}

# Public: dd_worktree_dir <issue-id> <slug>
dd_worktree_dir() {
  local issue="$1" slug="$2"
  local base name
  base="$(dd_path worktree_base)" || return $?
  name="$(_dd_paths_subst_tokens "$(cfg_get worktree.naming)" "$issue" "$slug")" || return $?
  printf '%s/%s\n' "${base%/}" "$name"
}
