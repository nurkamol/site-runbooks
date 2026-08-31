#!/usr/bin/env bash
#
# These runbooks are public and came from private client work. This keeps the
# second fact from leaking through the first.
#
# ── THE DENYLIST IS NOT IN THIS FILE, AND THAT IS THE POINT ────────────────
# The first version of this script listed client names, domains and people in
# plaintext, each helpfully labelled "# client", "# person", "# place". It was
# committed to a public repository. The guard could not see it because the
# script excludes itself from its own scan — necessarily, since its patterns
# would always match themselves.
#
# So the file whose job was to prevent exposure was the only file that caused
# it, and it was structurally invisible to every check including its own.
#
# Names now live OUTSIDE the repository, in a file git never sees. What ships
# here is structural only: shapes that are always wrong in a public document,
# and that name nobody.
set -u

# Shapes, not names. Safe to publish.
PATTERNS=(
  '/Users/[a-z]'                                   # machine paths
  '/home/[a-z]'
  'C:\\\\Users\\\\'
  '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'          # email addresses
  '\+[0-9]{7,15}'                                  # phone numbers, e164
  '\b[A-Z0-9]{20,}\b'                              # long tokens / keys
  'ghp_[A-Za-z0-9]{20,}'
  'sk-[A-Za-z0-9]{20,}'
)

# Client-specific names, one lowercase pattern per line, comments with '#'.
# Kept outside the repo so publishing this file cannot publish your client list.
DENYLIST="${SITE_RUNBOOKS_DENYLIST:-$HOME/.config/site-runbooks/denylist.txt}"
if [ -f "$DENYLIST" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | xargs)"
    [ -n "$line" ] && PATTERNS+=("$line")
  done < "$DENYLIST"
else
  echo "note: no denylist at $DENYLIST — checking structural patterns only."
  echo "      create it (one name per line) so client names are caught too."
fi

# Diff against HEAD, or the empty tree on a first commit — where `git diff
# --cached` alone returns nothing and the guard silently passes.
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  BASE=HEAD
else
  BASE=$(git hash-object -t tree /dev/null)
fi

# NOTE: this script no longer excludes itself. It contains no names to match,
# so it can be scanned like anything else — which is the property that makes
# the earlier leak impossible to repeat.
files=$(git diff --cached --name-only --diff-filter=ACM "$BASE" \
  | grep -E '\.(md|sh|mjs|json|ya?ml|txt)$' || true)
[ -z "$files" ] && exit 0

fail=0
for p in "${PATTERNS[@]}"; do
  hits=$(grep -rIniE "$p" $files 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "✗ blocked pattern matched:"
    echo "$hits" | sed 's/^/    /'
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  cat <<'MSG'

These runbooks are public. Something above identifies a client, a person, a
place, a machine or a credential.

Generalise it — "a production marketing site", "one shipped project" — and keep
the measurement, which is the part worth reading.
MSG
  exit 1
fi
echo "✓ no identifying content in staged files"
