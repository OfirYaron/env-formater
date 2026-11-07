#!/usr/bin/env bash
# Fails if secret material is tracked. This repo is PUBLIC and .gitignore can't stop
# `git add -f` or check what a template contains. (OYS-486)
#
# Prints file names and line numbers only, never matched text: CI logs here are public.
#
# Fails closed: if git or grep itself errors, the script exits non-zero rather than
# reporting a clean result. grep exit 1 only means "no match"; anything above is an error.
set -euo pipefail

status=0

# 1. Tracked files that .gitignore says should not be tracked. Uses .gitignore as the
#    only list of patterns, so the two can't drift apart.
ignored=$(git ls-files --cached --ignored --exclude-per-directory=.gitignore)
if [ -n "$ignored" ]; then
  echo "Tracked files that match .gitignore:"
  printf '%s\n' "$ignored" | sed 's/^/  /'
  status=1
fi

# 2. Templates must hold keys with empty values. The list is read up front because
#    `set -e` can't see a failure inside a process substitution.
templates=$(git ls-files -- '*.example')
while IFS= read -r template; do
  [ -n "$template" ] || continue
  rc=0
  lines=$(grep -nE '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*=[[:space:]]*[^[:space:]"'"'"']|^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*=[[:space:]]*("[^"]+"|'"'"'[^'"'"']+'"'"')' -- "$template" | cut -d: -f1 | paste -sd, -) || rc=$?
  [ "$rc" -le 1 ] || exit "$rc"
  if [ -n "$lines" ]; then
    echo "Template has non-empty values: $template (lines: $lines)"
    status=1
  fi
done <<< "$templates"

# 3. Well-known credential shapes in any tracked text file.
rc=0
shapes=$(git grep -IlE -e 'A[KS]IA[0-9A-Z]{16}' -e 'AIza[0-9A-Za-z_-]{35}' -e '-----BEGIN [A-Z ]*PRIVATE KEY-----') || rc=$?
[ "$rc" -le 1 ] || exit "$rc"
if [ -n "$shapes" ]; then
  echo "Files containing credential-shaped strings:"
  printf '%s\n' "$shapes" | sed 's/^/  /'
  status=1
fi

[ "$status" -eq 0 ] && echo "No tracked secrets found."
exit "$status"
