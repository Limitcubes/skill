#!/bin/bash
# Claude Limit Cubes — manual installer (run in a normal terminal, not Claude Code).
# The recommended path is the Claude Code plugin: see README.
set -e

SKILL_DIR="$HOME/.claude/skills/limitcubes"
SRC="$(cd "$(dirname "$0")" && pwd)/skills/limitcubes/SKILL.md"

if [ ! -f "$SRC" ]; then
  echo "error: run this from the cloned repo (skills/limitcubes/SKILL.md not found)" >&2
  exit 1
fi

echo "Installing LimitCubes skill → $SKILL_DIR"
mkdir -p "$SKILL_DIR"
cp "$SRC" "$SKILL_DIR/SKILL.md"

echo "✓ Installed. Open Claude Code and run:  /limitcubes start 0xYourWallet"
echo ""
echo "No runtime needed — the skill uses claude + curl, which you already have."
