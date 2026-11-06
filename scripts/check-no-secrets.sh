#!/usr/bin/env bash
# Fails if secret material is tracked. This repo is PUBLIC and .gitignore can't stop
# `git add -f` or check what a template contains. (OYS-486)
#
# Prints file names and line numbers only, never matched text: CI logs here are public.
set -uo pipefail

status=0

# 1. Tracked files that .gitignore says should not be tracked. Uses .gitignore as the
#    only list of patterns, so the two can't drift apart.
ignored=$(git ls-files --cached --ignored --exclude-standard)
if [ -n "$ignored" ]; then
  echo "Tracked files that match .gitignore:"
  printf '  %s\n' "$ignored"
  status=1
fi

# 2. Templates must hold keys with empty values.
while IFS= read -r template; do
  [ -n "$template" ] || continue
  lines=$(grep -nE '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*=[[:space:]]*[^[:space:]"'"'"']|^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*=[[:space:]]*("[^"]+"|'"'"'[^'"'"']+'"'"')' "$template" | cut -d: -f1 | paste -sd, -)
  if [ -n "$lines" ]; then
    echo "Template has non-empty values: $template (lines: $lines)"
    status=1
  fi
done < <(git ls-files -- '*.example')

# 3. Well-known credential shapes in any tracked text file.
shapes=$(git grep -IlE -e 'A[KS]IA[0-9A-Z]{16}' -e 'AIza[0-9A-Za-z_-]{35}' -e '-----BEGIN [A-Z ]*PRIVATE KEY-----')
if [ -n "$shapes" ]; then
  echo "Files containing credential-shaped strings:"
  printf '  %s\n' "$shapes"
  status=1
fi

[ "$status" -eq 0 ] && echo "No tracked secrets found."
exit "$status"
