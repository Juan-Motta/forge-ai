#!/usr/bin/env bash
#
# forge-ai installer — copy the workflow discipline into a target project.
#
#   ./install.sh <target-dir> [--upgrade]
#
# Copy-based on purpose: the discipline travels with the target repo (works on any
# clone, no external dependency). Re-run with --upgrade to refresh the framework files.
#
# MANAGED (framework baseline — OVERWRITTEN on install/upgrade):
#   CLAUDE.md, skills/, shared/rules/, docs/extending.md, *.template.md
# PROJECT-OWNED (created only if missing — NEVER clobbered):
#   PROJECT.md, CONTINUITY.md, .claude/settings.json, .codex/config.toml, opencode.json
#
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"
MODE="${2:-install}"

[ -n "$TARGET" ] || { echo "usage: $0 <target-dir> [--upgrade]" >&2; exit 2; }
[ -d "$TARGET" ] || { echo "error: target dir not found: $TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"
[ "$TARGET" != "$SRC" ] || { echo "error: refusing to install into forge-ai itself" >&2; exit 2; }

echo "forge-ai → installing into: $TARGET  (mode: $MODE)"

# --- MANAGED: CLAUDE.md (back up a pre-existing, non-forge one on first install) ---
if [ -f "$TARGET/CLAUDE.md" ] && ! grep -q "Workflow discipline for Claude Code" "$TARGET/CLAUDE.md" 2>/dev/null; then
  cp "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.md.pre-forge.bak"
  echo "  ! backed up existing CLAUDE.md -> CLAUDE.md.pre-forge.bak (move project-specifics into PROJECT.md)"
fi
cp "$SRC/CLAUDE.md" "$TARGET/CLAUDE.md"

# --- MANAGED: skills/ and shared/rules/ (clean replace) ---
rm -rf "$TARGET/skills"; cp -R "$SRC/skills" "$TARGET/skills"
mkdir -p "$TARGET/shared"; rm -rf "$TARGET/shared/rules"; cp -R "$SRC/shared/rules" "$TARGET/shared/rules"

# --- MANAGED: templates + framework doc + docs/ scaffolding ---
cp "$SRC/state.template.md" "$TARGET/state.template.md"
cp "$SRC/CONTINUITY.template.md" "$TARGET/CONTINUITY.template.md"
cp "$SRC/PROJECT.template.md" "$TARGET/PROJECT.template.md"
mkdir -p "$TARGET/docs"; cp "$SRC/docs/extending.md" "$TARGET/docs/extending.md"
for d in prds plans research solutions adr; do
  mkdir -p "$TARGET/docs/$d"
  [ -e "$TARGET/docs/$d/.gitkeep" ] || touch "$TARGET/docs/$d/.gitkeep"
done

# --- PROJECT-OWNED: create only if missing ---
[ -f "$TARGET/PROJECT.md" ]    || { cp "$SRC/PROJECT.template.md" "$TARGET/PROJECT.md"; echo "  + created PROJECT.md (fill in persona/info/variables/special rules)"; }
[ -f "$TARGET/CONTINUITY.md" ] || cp "$SRC/CONTINUITY.template.md" "$TARGET/CONTINUITY.md"
mkdir -p "$TARGET/.claude" "$TARGET/.codex" "$TARGET/.opencode"
[ -f "$TARGET/.claude/settings.json" ] || cp "$SRC/.claude/settings.json" "$TARGET/.claude/settings.json"
[ -f "$TARGET/.codex/config.toml" ]    || cp "$SRC/.codex/config.toml" "$TARGET/.codex/config.toml"
[ -f "$TARGET/opencode.json" ]         || cp "$SRC/opencode.json" "$TARGET/opencode.json"

# --- symlinks (guarded: never clobber or nest inside a pre-existing real file/dir) ---
# AGENTS.md → CLAUDE.md (back up a real, non-symlink AGENTS.md first)
if [ -e "$TARGET/AGENTS.md" ] && [ ! -L "$TARGET/AGENTS.md" ]; then
  mv "$TARGET/AGENTS.md" "$TARGET/AGENTS.md.pre-forge.bak"
  echo "  ! backed up existing AGENTS.md -> AGENTS.md.pre-forge.bak"
fi
ln -sfn CLAUDE.md "$TARGET/AGENTS.md"

# per-engine skills symlink → ../skills
link_skills() {
  local lp="$TARGET/$1"
  if [ -L "$lp" ] || [ ! -e "$lp" ]; then
    ln -sfn ../skills "$lp"                 # symlink or absent → (re)create
  elif [ -d "$lp" ] && [ -z "$(ls -A "$lp")" ]; then
    rmdir "$lp"; ln -s ../skills "$lp"      # empty real dir → replace
  else
    echo "  ! $1 already exists as a non-empty directory — left as-is (NOT symlinked)."
    echo "    forge-ai skills live in ./skills. Move yours into ./skills, or keep them here"
    echo "    knowing forge-ai's skills won't be discovered via $1 for this engine."
  fi
}
link_skills ".claude/skills"
link_skills ".codex/skills"
link_skills ".opencode/skills"

# --- .gitignore (merge, don't clobber) ---
touch "$TARGET/.gitignore"
if ! grep -qx '.workflow/' "$TARGET/.gitignore"; then
  printf '\n# forge-ai\n.DS_Store\n.workflow/\n' >> "$TARGET/.gitignore"
fi

echo "forge-ai installed."
echo "  next: (1) fill PROJECT.md   (2) in Codex, trust the project when prompted"
echo "        (3) open the project in any of Claude Code / Codex / OpenCode"
