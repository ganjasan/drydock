#!/usr/bin/env bash
# Drydock plugin — SessionStart bridge.
#
# Wired into Claude Code's SessionStart event via hooks/hooks.json. Reads the
# session payload Claude Code provides on stdin (we ignore it — Drydock's hook
# protocol uses its own payload format), then dispatches to the per-repo
# session-start lifecycle hook via lib/hooks.sh::dd_hook_invoke.
#
# Per the extension-model contract, session-start is a "warn-don't-abort" hook:
# the per-repo script's non-zero exit is reported but does not interrupt the
# Claude Code session.

set -uo pipefail

# Drain Claude Code's payload from stdin so it doesn't block.
cat >/dev/null 2>&1 || true

# Source Drydock libs by absolute path (CLAUDE_PLUGIN_ROOT is set by the harness).
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/config.sh
source "${PLUGIN_ROOT}/lib/config.sh"
# shellcheck source=../lib/hooks.sh
source "${PLUGIN_ROOT}/lib/hooks.sh"

# Dispatch to the per-repo session-start hook (silently no-op if absent).
# session-start failure is a warning per the extension-model contract; we
# always exit 0 so Claude Code's session continues.
dd_hook_invoke session-start '{}' || true
exit 0
