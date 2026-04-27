#!/usr/bin/env bash
# Drydock — minimal test harness.
#
# A test file sources this and uses `dd_test_case` to declare each test.
# Failures print a diagnostic; the file exits with the count of failures.
#
# Usage:
#   source "$(dirname "$0")/_harness.sh"
#
#   dd_test_case "description" '
#     # body — set up state, call the function under test, assert.
#     out="$(some_function)"
#     dd_assert_eq "$out" "expected"
#   '
#
#   dd_test_summary
#
# All temp directories created by tests should live under $DD_TEST_TMPROOT and
# are cleaned up on exit by the harness EXIT trap.

set -uo pipefail   # not -e: tests may intentionally trigger non-zero returns

DD_TEST_PASS=0
DD_TEST_FAIL=0
DD_TEST_FAILURES=()
DD_TEST_TMPROOT="$(mktemp -d -t drydock-test-XXXXXX)"
trap 'rm -rf "$DD_TEST_TMPROOT"' EXIT

# Run a test case. The body is `eval`-d in a subshell so its exits and traps
# don't affect the outer harness.
dd_test_case() {
  local desc="$1" body="$2"
  if (
    set -uo pipefail
    eval "$body"
  ); then
    DD_TEST_PASS=$((DD_TEST_PASS + 1))
    printf '  ok   %s\n' "$desc"
  else
    DD_TEST_FAIL=$((DD_TEST_FAIL + 1))
    DD_TEST_FAILURES+=("$desc")
    printf '  FAIL %s\n' "$desc"
  fi
}

dd_assert_eq() {
  local got="$1" want="$2" msg="${3:-values differ}"
  if [ "$got" = "$want" ]; then return 0; fi
  printf '       %s\n        got:  %q\n        want: %q\n' "$msg" "$got" "$want" >&2
  return 1
}

dd_assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-substring not found}"
  case "$haystack" in
    *"$needle"*) return 0 ;;
  esac
  printf '       %s\n        haystack: %q\n        needle:   %q\n' "$msg" "$haystack" "$needle" >&2
  return 1
}

dd_assert_status_eq() {
  local got="$1" want="$2" msg="${3:-exit status differs}"
  if [ "$got" = "$want" ]; then return 0; fi
  printf '       %s\n        got:  %s\n        want: %s\n' "$msg" "$got" "$want" >&2
  return 1
}

# Allocate a fresh temp directory for a single test case.
dd_test_tmpdir() {
  mktemp -d "${DD_TEST_TMPROOT}/case-XXXXXX"
}

dd_test_summary() {
  local total=$((DD_TEST_PASS + DD_TEST_FAIL))
  printf '\n  %d passed, %d failed (of %d)\n' "$DD_TEST_PASS" "$DD_TEST_FAIL" "$total"
  if [ "$DD_TEST_FAIL" -gt 0 ]; then
    printf '  failures:\n'
    for f in "${DD_TEST_FAILURES[@]}"; do printf '    - %s\n' "$f"; done
    exit 1
  fi
  exit 0
}
