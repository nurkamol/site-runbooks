#!/usr/bin/env bash
#
# Install the skill so `site-runbooks` is available in every project on this
# machine, without copying it.
#
# It SYMLINKS rather than copies, deliberately. A copied skill is a second
# vintage of the same instructions — which is the failure these runbooks are
# about. Linked, `git pull` here updates the skill everywhere at once.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/site-runbooks"

mkdir -p "$(dirname "$DEST")"

if [ -L "$DEST" ]; then
  rm "$DEST"
elif [ -e "$DEST" ]; then
  echo "✗ $DEST exists and is not a symlink."
  echo "  Move it aside, then run this again — refusing to delete a real directory."
  exit 1
fi

ln -s "$REPO/skill" "$DEST"
echo "✓ linked $DEST → $REPO/skill"
echo "  The skill now tracks this repo. Pull here and it updates everywhere."

# ── AND THE HOOK, WHICH A CLONE DOES NOT BRING WITH IT ────────────────────
# core.hooksPath lives in .git/config, and .git/config is not cloned. So a
# fresh clone of this repository has NO pre-commit guard at all until this
# runs — verified by cloning it and successfully committing a client name.
#
# The guard being in the tree is not the same as the guard being installed.
git -C "$REPO" config core.hooksPath .githooks
echo "✓ pre-commit guard enabled (core.hooksPath → .githooks)"

DENYLIST="${SITE_RUNBOOKS_DENYLIST:-$HOME/.config/site-runbooks/denylist.txt}"
if [ ! -f "$DENYLIST" ]; then
  mkdir -p "$(dirname "$DENYLIST")"
  cat > "$DENYLIST" <<'SEED'
# Client-identifying names. NEVER committed — this file lives outside any repo.
# One lowercase regex per line. Add a name the day a client's work informs a
# runbook, not later.
SEED
  echo "✓ created $DENYLIST — add your client names to it"
else
  echo "✓ denylist already at $DENYLIST"
fi
