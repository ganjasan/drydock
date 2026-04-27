#!/usr/bin/env bash
# Drydock dogfood pre-pr hook.
# Asserts traces_to frontmatter is present in any added/modified ADR or
# use-case file in this PR. Treats absent traces_to as a refusal reason.
set -euo pipefail

payload="$(cat)"
commits="$(jq -r '.commits[]?'      <<<"$payload")"
repo_path="$(jq -r '.repo_path'     <<<"$payload")"

cd "$repo_path"
violations=()
for sha in $commits; do
  for f in $(git diff-tree --no-commit-id --name-only --diff-filter=AM -r "$sha" 2>/dev/null); do
    case "$f" in
      requirements/adr/*.md|requirements/use-cases/*.md)
        if [ -f "$f" ] && ! awk '/^---$/{c++; next} c==1{print}' "$f" | grep -qE '^traces_to:' ; then
          violations+=("  - $f (commit $sha) is missing traces_to frontmatter")
        fi
        ;;
    esac
  done
done

if [ "${#violations[@]}" -gt 0 ]; then
  echo "pre-pr: traces_to frontmatter required for ADR/use-case files" >&2
  printf '%s\n' "${violations[@]}" >&2
  exit 1
fi
exit 0
