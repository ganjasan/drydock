#!/usr/bin/env bash
# Tests for lib/paths.sh.

# shellcheck source=_harness.sh
source "$(dirname "$0")/_harness.sh"

DD_LIB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

printf 'paths.sh: dd_path / dd_branch_name / dd_worktree_dir\n'

dd_test_case "dd_path requirements with default config" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"

  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        dd_path requirements
      "
  )
  dd_assert_eq "$out" "$tmp/repo/requirements"
'

dd_test_case "dd_path requirements honors override" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
paths:
  requirements: docs/req
EOF
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        dd_path requirements
      "
  )
  dd_assert_eq "$out" "$tmp/repo/docs/req"
'

dd_test_case "dd_path requirements_subdir vision" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        dd_path requirements_subdir vision
      "
  )
  dd_assert_eq "$out" "$tmp/repo/requirements/vision"
'

dd_test_case "dd_path raw_root with override" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
paths:
  raw_root: signals
EOF
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        dd_path raw_root
      "
  )
  dd_assert_eq "$out" "$tmp/repo/signals"
'

dd_test_case "dd_path worktree_base relative joined to repo root" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        dd_path worktree_base
      "
  )
  dd_assert_eq "$out" "$tmp/repo/.worktrees"
'

dd_test_case "dd_path worktree_base absolute used verbatim" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
worktree:
  base_dir: /var/worktrees
EOF
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        dd_path worktree_base
      "
  )
  dd_assert_eq "$out" "/var/worktrees"
'

dd_test_case "dd_branch_name default template" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        dd_branch_name 42 dark-mode
      "
  )
  dd_assert_eq "$out" "feature/42-dark-mode"
'

dd_test_case "dd_branch_name custom template" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
worktree:
  branch_naming: "issue/<issue-id>/<slug>"
EOF
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        dd_branch_name 42 dark-mode
      "
  )
  dd_assert_eq "$out" "issue/42/dark-mode"
'

dd_test_case "dd_branch_name rejects unknown token" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
worktree:
  branch_naming: "feature/<issue-id>-<area>"
EOF
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        set +e
        dd_branch_name 42 dark-mode 2>&1
        echo STATUS=\$?
      "
  )
  dd_assert_contains "$out" "unknown token"
  dd_assert_contains "$out" "STATUS=2"
'

dd_test_case "dd_worktree_dir composes base + naming" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/paths.sh\"
        dd_worktree_dir 42 dark-mode
      "
  )
  dd_assert_eq "$out" "$tmp/repo/.worktrees/wt-42"
'

dd_test_summary
