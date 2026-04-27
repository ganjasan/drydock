#!/usr/bin/env bash
# Tests for lib/config.sh three-layer merge.

# shellcheck source=_harness.sh
source "$(dirname "$0")/_harness.sh"

DD_LIB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Each test case isolates plugin/user/repo configs in a tmpdir, sets the
# corresponding env vars, sources config.sh, and asserts on cfg_get output.
# We override _dd_repo_root by chdir-ing into the per-test repo dir.

printf 'config.sh: three-layer merge\n'

dd_test_case "per-repo overrides user-level overrides plugin-root" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home/.drydock" "$tmp/repo/.drydock" "$tmp/repo/.git"

  cat > "$tmp/plugin/config.yaml" <<EOF
worktree:
  enabled: false
EOF
  cat > "$tmp/home/.drydock/config.yaml" <<EOF
worktree:
  enabled: true
EOF
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
worktree:
  enabled: false
EOF

  CLAUDE_PLUGIN_ROOT="$tmp/plugin" \
  HOME="$tmp/home" \
  DRYDOCK_CONFIG_PATH="" _DD_CONFIG_TMPDIR="" \
    bash -c "
      cd \"$tmp/repo\"
      source \"${DD_LIB_DIR}/config.sh\"
      val=\$(cfg_get worktree.enabled)
      [ \"\$val\" = \"false\" ]
    "
'

dd_test_case "user-level overrides plugin-root when no per-repo" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home/.drydock" "$tmp/repo/.git"

  cat > "$tmp/plugin/config.yaml" <<EOF
worktree:
  enabled: false
EOF
  cat > "$tmp/home/.drydock/config.yaml" <<EOF
worktree:
  enabled: true
EOF

  CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
    bash -c "
      cd \"$tmp/repo\"
      source \"${DD_LIB_DIR}/config.sh\"
      val=\$(cfg_get worktree.enabled)
      [ \"\$val\" = \"true\" ]
    "
'

dd_test_case "plugin-root used when no user-level and no per-repo" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"

  cat > "$tmp/plugin/config.yaml" <<EOF
github:
  triage_label: needs-triage
EOF

  CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
    bash -c "
      cd \"$tmp/repo\"
      source \"${DD_LIB_DIR}/config.sh\"
      val=\$(cfg_get github.triage_label)
      [ \"\$val\" = \"needs-triage\" ]
    "
'

dd_test_case "all layers absent uses built-in default" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"

  CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
    bash -c "
      cd \"$tmp/repo\"
      source \"${DD_LIB_DIR}/config.sh\"
      val=\$(cfg_get paths.requirements)
      [ \"\$val\" = \"requirements\" ]
    "
'

dd_test_case "maps merge key-by-key (area_to_repo)" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"

  cat > "$tmp/plugin/config.yaml" <<EOF
area_to_repo:
  a: x
  b: y
EOF
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
area_to_repo:
  b: z
  c: w
EOF

  CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
    bash -c "
      cd \"$tmp/repo\"
      source \"${DD_LIB_DIR}/config.sh\"
      [ \"\$(cfg_get area_to_repo.a)\" = \"x\" ] || exit 1
      [ \"\$(cfg_get area_to_repo.b)\" = \"z\" ] || exit 1
      [ \"\$(cfg_get area_to_repo.c)\" = \"w\" ] || exit 1
    "
'

dd_test_case "lists are replaced wholesale (release.gates)" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"

  cat > "$tmp/plugin/config.yaml" <<EOF
release:
  gates:
    - /dd:build:test
    - /old-gate
EOF
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
release:
  gates:
    - /conformance
EOF

  CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
    bash -c "
      cd \"$tmp/repo\"
      source \"${DD_LIB_DIR}/config.sh\"
      out=\$(cfg_array_get release.gates)
      [ \"\$out\" = \"/conformance\" ]
    "
'

dd_test_case "alternate location <repo>/drydock.yaml is rejected" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"
  echo "anything: 1" > "$tmp/repo/drydock.yaml"

  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/config.sh\" 2>&1
        cfg_get worktree.enabled 2>&1
      " 2>&1
    echo "STATUS=$?"
  )
  dd_assert_contains "$out" "non-supported location"
'

dd_test_case "alternate location <repo>/.drydock.yaml is rejected" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.git"
  echo "anything: 1" > "$tmp/repo/.drydock.yaml"

  out=$(
    CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
      bash -c "
        cd \"$tmp/repo\"
        source \"${DD_LIB_DIR}/config.sh\" 2>&1
        cfg_get worktree.enabled 2>&1
      " 2>&1
    echo "STATUS=$?"
  )
  dd_assert_contains "$out" "non-supported location"
'

dd_test_case "DRYDOCK_CONFIG_PATH points at a real file with merged content" '
  tmp="$(dd_test_tmpdir)"
  mkdir -p "$tmp/plugin" "$tmp/home" "$tmp/repo/.drydock" "$tmp/repo/.git"
  cat > "$tmp/plugin/config.yaml" <<EOF
github:
  triage_label: plugin-default
EOF
  cat > "$tmp/repo/.drydock/config.yaml" <<EOF
github:
  triage_label: repo-override
EOF

  CLAUDE_PLUGIN_ROOT="$tmp/plugin" HOME="$tmp/home" \
    bash -c "
      cd \"$tmp/repo\"
      source \"${DD_LIB_DIR}/config.sh\"
      dd_config_load
      [ -f \"\$DRYDOCK_CONFIG_PATH\" ] || exit 1
      [ \"\$(jq -r .github.triage_label \"\$DRYDOCK_CONFIG_PATH\")\" = \"repo-override\" ] || exit 2
    "
'

dd_test_summary
