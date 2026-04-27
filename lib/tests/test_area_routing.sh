#!/usr/bin/env bash
# Tests for lib/area_routing.sh.

# shellcheck source=_harness.sh
source "$(dirname "$0")/_harness.sh"

DD_LIB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

printf 'area_routing.sh: dd_resolve_area edge cases\n'

dd_test_case "no area_to_repo configured → current repo" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/area_routing.sh\"
        dd_resolve_area frontend
      "
  )
  dd_assert_eq "$out" "$tmp/repo"
'

dd_test_case "area_to_repo set but area missing → fail loud" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
area_to_repo:
  frontend: ../fe
EOF
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/area_routing.sh\"
        set +e
        dd_resolve_area backend 2>&1
        echo STATUS=\$?
      "
  )
  dd_assert_contains "$out" "no entry in area_to_repo"
  dd_assert_contains "$out" "STATUS=1"
'

dd_test_case "value \".\" → current repo" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
area_to_repo:
  docs: .
EOF
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/area_routing.sh\"
        dd_resolve_area docs
      "
  )
  dd_assert_eq "$out" "$tmp/repo"
'

dd_test_case "absolute path used verbatim" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
area_to_repo:
  shared: /opt/shared-repo
EOF
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/area_routing.sh\"
        dd_resolve_area shared
      "
  )
  dd_assert_eq "$out" "/opt/shared-repo"
'

dd_test_case "relative path resolved against parent of current repo (sibling-name pattern)" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/work/hub/.drydock" "$tmp/work/hub/.git"
  cat > "$tmp/work/hub/.drydock/config.yaml" <<EOF
area_to_repo:
  frontend: frontend
EOF
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/work/hub\"
        source \"${DD_LIB_DIR}/area_routing.sh\"
        dd_resolve_area frontend
      "
  )
  dd_assert_eq "$out" "$tmp/work/frontend"
'

dd_test_summary
