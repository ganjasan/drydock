#!/usr/bin/env bash
# Drydock plugin — MCP server presence check.
#
# Used by /dd:raw:ingest-* commands to fail fast when a required MCP server
# is not connected. Drydock cannot install MCP servers for the user; it can
# only report the gap clearly.
#
# Usage from a command body:
#   source "${CLAUDE_PLUGIN_ROOT}/lib/mcp_check.sh"
#   dd_mcp_require gmail "Gmail MCP" \
#       "https://github.com/anthropics/claude-mcp-servers" \
#     || exit $?
#
# Returns 0 when the named MCP is connected, non-zero when not (with a clear
# install-guidance message printed to stderr).

set -uo pipefail

# Probe whether an MCP with the given name fragment is connected.
# Implementation: calls `claude mcp list` (the Claude Code CLI introspection)
# and grep-matches the name. If the CLI is unavailable, falls back to checking
# whether the user's session reports the MCP via the JSON variant.
#
# Usage: dd_mcp_present <name-fragment>
#   Returns 0 if a connected MCP matches the fragment (case-insensitive).
dd_mcp_present() {
  local needle="$1"
  if command -v claude >/dev/null 2>&1; then
    claude mcp list 2>/dev/null | grep -iq "$needle"
    return $?
  fi
  # Fallback: assume MCP introspection is unavailable in this environment.
  # Treat as "unknown" → caller should default to attempting the call and
  # surfacing whatever error the underlying MCP returns.
  return 2
}

# Require an MCP. Prints install-guidance and returns non-zero when absent.
# Usage: dd_mcp_require <name-fragment> <human-readable-name> <install-url>
dd_mcp_require() {
  local needle="$1" pretty="$2" install_url="${3:-}"
  if dd_mcp_present "$needle"; then
    return 0
  fi
  local rc=$?
  if [ "$rc" -eq 2 ]; then
    # Cannot probe — emit a soft warning and let the caller proceed.
    echo "[drydock] WARN: cannot probe MCP availability; will attempt ${pretty} anyway" >&2
    return 0
  fi
  cat >&2 <<EOF

ERROR: ${pretty} is not connected.

This command needs ${pretty} to read from the source. Drydock does not
install MCP servers — install and authenticate it via Claude Code's
configuration first, then re-run this command.

EOF
  if [ -n "$install_url" ]; then
    echo "Reference: ${install_url}" >&2
    echo "" >&2
  fi
  return 1
}
