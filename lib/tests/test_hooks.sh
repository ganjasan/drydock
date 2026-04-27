#!/usr/bin/env bash
# Tests for lib/hooks.sh dispatch.

# shellcheck source=_harness.sh
source "$(dirname "$0")/_harness.sh"

DD_LIB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

printf 'hooks.sh: lifecycle dispatch\n'

dd_test_case "missing hook is silently skipped" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"

  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/hooks.sh\"
        dd_hook_invoke pre-pr \"{\\\"branch\\\":\\\"x\\\"}\" 2>&1
        echo STATUS=\$?
      " 2>&1
  )
  dd_assert_contains "$out" "STATUS=0" "missing hook should return 0 silently"
  case "$out" in
    *WARN*|*ERROR*) return 1 ;;
  esac
'

dd_test_case "non-executable hook emits warning and is skipped" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock/hooks" "$tmp/repo/.git"
  echo "exit 5" > "$tmp/repo/.drydock/hooks/pre-pr.sh"
  # Intentionally NOT chmod +x.

  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/hooks.sh\"
        dd_hook_invoke pre-pr \"{}\" 2>&1
        echo STATUS=\$?
      " 2>&1
  )
  dd_assert_contains "$out" "WARN" "expected warning for non-executable hook"
  dd_assert_contains "$out" "STATUS=0" "non-exec should not abort"
'

dd_test_case "executable pre-* hook with success exits 0" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock/hooks" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/hooks/pre-pr.sh" <<EOF
#!/usr/bin/env bash
read payload
exit 0
EOF
  chmod +x "$tmp/repo/.drydock/hooks/pre-pr.sh"

  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/hooks.sh\"
        dd_hook_invoke pre-pr \"{}\" 2>&1
        echo STATUS=\$?
      " 2>&1
  )
  dd_assert_contains "$out" "STATUS=0"
'

dd_test_case "pre-* hook failure aborts with non-zero exit" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock/hooks" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/hooks/pre-pr.sh" <<EOF
#!/usr/bin/env bash
read payload
exit 7
EOF
  chmod +x "$tmp/repo/.drydock/hooks/pre-pr.sh"

  # set +e in the inner shell so we can capture the dispatcher exit code
  # without bash -c being aborted by set -e from hooks.sh.
  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/hooks.sh\"
        set +e
        dd_hook_invoke pre-pr \"{}\" 2>&1
        echo STATUS=\$?
      " 2>&1
  )
  dd_assert_contains "$out" "ERROR"
  dd_assert_contains "$out" "STATUS=7"
'

dd_test_case "post-* hook failure warns but returns 0 to caller" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock/hooks" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/hooks/post-archive.sh" <<EOF
#!/usr/bin/env bash
read payload
exit 3
EOF
  chmod +x "$tmp/repo/.drydock/hooks/post-archive.sh"

  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/hooks.sh\"
        dd_hook_invoke post-archive \"{}\" 2>&1
        echo STATUS=\$?
      " 2>&1
  )
  dd_assert_contains "$out" "WARN"
  dd_assert_contains "$out" "STATUS=0" "post-* failure should not abort"
'

dd_test_case "session-start failure warns but returns 0" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock/hooks" "$tmp/repo/.git"
  cat > "$tmp/repo/.drydock/hooks/session-start.sh" <<EOF
#!/usr/bin/env bash
read payload
exit 9
EOF
  chmod +x "$tmp/repo/.drydock/hooks/session-start.sh"

  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/hooks.sh\"
        dd_hook_invoke session-start \"{}\" 2>&1
        echo STATUS=\$?
      " 2>&1
  )
  dd_assert_contains "$out" "WARN"
  dd_assert_contains "$out" "STATUS=0"
'

dd_test_case "payload contains required fields and merged extras" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock/hooks" "$tmp/repo/.git"
  capture="$tmp/payload.json"
  cat > "$tmp/repo/.drydock/hooks/pre-pr.sh" <<EOF
#!/usr/bin/env bash
cat > "$capture"
exit 0
EOF
  chmod +x "$tmp/repo/.drydock/hooks/pre-pr.sh"

  CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
    bash -c "
      cd \"$tmp/repo\"
      source \"${DD_LIB_DIR}/hooks.sh\"
      dd_hook_invoke pre-pr \"{\\\"branch\\\":\\\"feature/42-x\\\",\\\"commits\\\":[\\\"sha1\\\",\\\"sha2\\\"]}\" >/dev/null 2>&1
    "

  [ -f "$capture" ] || { echo "payload not captured" >&2; return 1; }
  [ "$(jq -r .event "$capture")" = "pre-pr" ] || return 2
  [ "$(jq -r .branch "$capture")" = "feature/42-x" ] || return 3
  [ "$(jq -r ".commits | length" "$capture")" = "2" ] || return 4
  [ -n "$(jq -r .repo_path "$capture")" ] || return 5
  [ -n "$(jq -r .config_path "$capture")" ] || return 6
'

dd_test_summary
