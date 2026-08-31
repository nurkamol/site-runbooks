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
