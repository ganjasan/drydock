#!/usr/bin/env bash
# Drydock plugin — GitHub Project field setter.
#
# Opt-in helper for /dd:plan:* commands to set Project v2 field values on an
# issue. No-ops when the field block is unconfigured — never errors and never
# emits warnings for absent configuration. Errors only when configured but the
# `gh` call fails.
#
# Public API:
#   dd_project_field_set <issue-node-id> <field-name> <option-name>
#     - field-name:  status | priority | area | phase  (or any custom field
#                    declared under github.project_fields.<name>)
#     - option-name: a key under github.project_fields.<field>.options
#     Returns 0 on success or when field is unconfigured.
#     Returns non-zero when configured but gh call fails.

set -uo pipefail

if ! command -v dd_config_load >/dev/null 2>&1; then
  # shellcheck source=lib/config.sh
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

dd_project_field_set() {
  local item_id="$1" field="$2" option="$3"
  dd_config_load >/dev/null

  # Project must be declared.
  cfg_has github.project.id || return 0

  # Field must be declared with id + options.
  local field_id option_id
  field_id="$(cfg_get "github.project_fields.${field}.id")"
  [ -n "$field_id" ] || return 0   # field unconfigured: silent no-op

  option_id="$(cfg_get "github.project_fields.${field}.options.${option}")"
  if [ -z "$option_id" ]; then
    echo "[drydock] WARN: option '${option}' not found in github.project_fields.${field}.options; skipping" >&2
    return 0
  fi

  local project_id
  project_id="$(cfg_get github.project.id)"

  if ! command -v gh >/dev/null 2>&1; then
    echo "[drydock] ERROR: gh CLI required for project field updates but not installed" >&2
    return 1
  fi

  gh project item-edit \
    --id "$item_id" \
    --project-id "$project_id" \
    --field-id "$field_id" \
    --single-select-option-id "$option_id" \
    >/dev/null 2>&1
}
