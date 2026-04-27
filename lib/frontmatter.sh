#!/usr/bin/env bash
# Drydock plugin — YAML frontmatter helpers.
#
# Used by ADR auto-numbering, slug generation, and traceability checks.
# `yq` is optional; the helpers fall back to awk/sed.

set -euo pipefail

# Extract the frontmatter block (between --- markers) from a Markdown file.
fm_extract() {
  local file="$1"
  awk '/^---$/{c++; if(c==2) exit; next} c==1{print}' "$file"
}

# Get a single top-level scalar from frontmatter (no nested support without yq).
# Usage: fm_get <file> <key>
fm_get() {
  local file="$1" key="$2"
  fm_extract "$file" | awk -v k="$key" -F: '$1==k{sub(/^[^:]*:[ \t]*/, ""); print; exit}'
}

# sha256 of the body (post-frontmatter).
fm_content_hash() {
  local file="$1"
  awk 'BEGIN{skip=0} /^---$/{if(skip<2){skip++; next}} skip>=2{print}' "$file" | sha256sum | cut -d' ' -f1
}

# Validate required frontmatter keys are present.
# Usage: fm_require <file> key1 key2 ...
fm_require() {
  local file="$1"; shift
  local missing=()
  for k in "$@"; do
    if [ -z "$(fm_get "$file" "$k")" ]; then
      missing+=("$k")
    fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: $file missing frontmatter keys: ${missing[*]}" >&2
    return 1
  fi
}

# 6-char random alphanumeric id (lowercase).
fm_gen_id() {
  tr -dc 'a-z0-9' </dev/urandom | head -c6
}

# Build a filename slug from a free-form title.
# Usage: fm_slug "Some Title Here"  → "some-title-here"
fm_slug() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]\+/-/g; s/^-\+//; s/-\+$//' \
    | cut -c1-60
}

# Next ADR number in a directory (4-digit padded).
# Looks for files named NNNN-*.md and picks max + 1.
# Usage: fm_next_adr_number <adr-dir>
fm_next_adr_number() {
  local dir="$1"
  [ -d "$dir" ] || { printf '%04d\n' 1; return 0; }
  local max=0 n
  for f in "$dir"/[0-9][0-9][0-9][0-9]-*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" | sed -n 's/^\([0-9][0-9][0-9][0-9]\)-.*/\1/p')"
    n="${n#0}"; n="${n#0}"; n="${n#0}"
    [ -z "$n" ] && n=0
    if [ "$n" -gt "$max" ]; then max="$n"; fi
  done
  printf '%04d\n' "$((max + 1))"
}
