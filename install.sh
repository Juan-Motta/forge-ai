#!/usr/bin/env bash
#
# forge-ai installer — copy the workflow discipline into a target project.
#
#   ./install.sh <target-dir> [--upgrade]
#
# The shippable payload is the NEUTRAL source in ./src/ (CLAUDE.md, skills/, shared/rules/,
# configs/, sync.sh/ps1, docs/, *.template.md). Keeping it in a subfolder keeps the repo
# root free of files that would collide when working ON forge-ai (e.g. a root CLAUDE.md or
# docs/). This installer copies src/* into the target's root, then runs sync.sh to GENERATE
# each engine's config + skills
# (.claude/.codex/.opencode + AGENTS.md + opencode.json). No symlinks anywhere
# (Windows-safe). The generated engine artifacts are gitignored — regenerate them any time
# with ./sync.sh (or sync.ps1).
#
# Copy-based on purpose: the discipline travels with the target repo (works on any clone,
# no external dependency). Re-run with --upgrade to refresh the framework files.
#
# MANAGED (framework baseline — OVERWRITTEN on install/upgrade):
#   CLAUDE.md, sync.sh/sync.ps1, docs/extending.md, *.template.md, and the framework's OWN
#   entries in skills/ and shared/rules/ (refreshed by name). Your own skills/rules dropped
#   into those dirs are left untouched — they survive upgrades (selective, not wholesale).
# PROJECT-OWNED (created only if missing — NEVER clobbered):
#   PROJECT.md, CONTINUITY.md, configs/claude/settings.json, configs/codex/config.toml,
#   configs/opencode.json  (edit these to customize; sync regenerates the engine dirs)
# GENERATED (gitignored; produced by sync.sh — do NOT edit):
#   AGENTS.md, opencode.json, .claude/, .agents/, .codex/
#   (skills live in .claude/skills for Claude Code + .agents/skills for Codex; OpenCode
#    reads either — verified per each engine's docs.)
#
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SRC/src"
TARGET="${1:-}"
MODE="${2:-install}"

[ -n "$TARGET" ] || { echo "usage: $0 <target-dir> [--upgrade]" >&2; exit 2; }
[ -d "$TARGET" ] || { echo "error: target dir not found: $TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"
[ "$TARGET" != "$SRC" ] || { echo "error: refusing to install into forge-ai itself" >&2; exit 2; }
{ [ -f "$PAYLOAD/CLAUDE.md" ] && [ -d "$PAYLOAD/skills" ]; } || { echo "error: payload not found — run this from the forge-ai repo root" >&2; exit 2; }

echo "forge-ai → installing into: $TARGET  (mode: $MODE)"

# --- MANAGED: CLAUDE.md (back up a pre-existing, non-forge one on first install) ---
if [ -f "$TARGET/CLAUDE.md" ] && ! grep -q "Workflow discipline for Claude Code" "$TARGET/CLAUDE.md" 2>/dev/null; then
  cp "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.md.pre-forge.bak"
  echo "  ! backed up existing CLAUDE.md -> CLAUDE.md.pre-forge.bak (move project-specifics into PROJECT.md)"
fi
cp "$PAYLOAD/CLAUDE.md" "$TARGET/CLAUDE.md"

# --- MANAGED: framework skills/ and shared/rules/ (per-entry overwrite by name) ---
# Refresh only the framework's own entries; anything else in these dirs (your project's
# own skills/rules) is left untouched, so it survives --upgrade.
mkdir -p "$TARGET/skills" "$TARGET/shared/rules"
for d in "$PAYLOAD"/skills/*/; do
  name="$(basename "$d")"
  rm -rf "$TARGET/skills/$name"
  cp -R "$d" "$TARGET/skills/$name"
done
for f in "$PAYLOAD"/shared/rules/*.md; do
  cp "$f" "$TARGET/shared/rules/$(basename "$f")"
done

# --- MANAGED: sync scripts (the generator) ---
cp "$PAYLOAD/sync.sh" "$TARGET/sync.sh"; chmod +x "$TARGET/sync.sh"
cp "$PAYLOAD/sync.ps1" "$TARGET/sync.ps1"

# --- MANAGED: templates + framework doc + docs/ scaffolding ---
cp "$PAYLOAD/state.template.md" "$TARGET/state.template.md"
cp "$PAYLOAD/CONTINUITY.template.md" "$TARGET/CONTINUITY.template.md"
cp "$PAYLOAD/PROJECT.template.md" "$TARGET/PROJECT.template.md"
mkdir -p "$TARGET/docs"; cp "$PAYLOAD/docs/extending.md" "$TARGET/docs/extending.md"
for d in prds plans research solutions adr; do
  mkdir -p "$TARGET/docs/$d"
  [ -e "$TARGET/docs/$d/.gitkeep" ] || touch "$TARGET/docs/$d/.gitkeep"
done

# --- PROJECT-OWNED: PROJECT.md / CONTINUITY.md (create only if missing) ---
[ -f "$TARGET/PROJECT.md" ]    || { cp "$PAYLOAD/PROJECT.template.md" "$TARGET/PROJECT.md"; echo "  + created PROJECT.md (fill in persona/info/variables/special rules)"; }
[ -f "$TARGET/CONTINUITY.md" ] || cp "$PAYLOAD/CONTINUITY.template.md" "$TARGET/CONTINUITY.md"

# --- PROJECT-OWNED: neutral configs (create if missing; migrate a pre-existing engine
#     config so we don't lose the project's own gate settings) ---
seed_config() {  # $1 = configs/ path (source of truth), $2 = pre-existing generated path
  local cfg="$TARGET/$1" pre="$TARGET/$2"
  [ -f "$cfg" ] && return 0
  mkdir -p "$(dirname "$cfg")"
  if [ -f "$pre" ]; then
    cp "$pre" "$cfg"; echo "  + migrated existing $2 -> $1 (edit configs/ from now on)"
  else
    cp "$PAYLOAD/$1" "$cfg"
  fi
}
seed_config configs/claude/settings.json .claude/settings.json
seed_config configs/codex/config.toml    .codex/config.toml
seed_config configs/opencode.json        opencode.json

# --- back up any pre-existing, NON-forge per-engine skills dir before sync overwrites it ---
# (forge-generated dirs carry a .forge-generated marker; a dir without it is the user's own,
#  so we never wipe a user's skills — even one coincidentally named new-feature.)
for eng in .claude .agents; do
  sd="$TARGET/$eng/skills"
  if [ -e "$sd" ] && [ ! -e "$sd/.forge-generated" ]; then
    mv "$sd" "$sd.pre-forge.bak"
    echo "  ! backed up existing $eng/skills -> $eng/skills.pre-forge.bak (put custom skills in ./skills)"
  fi
done
# back up a real, non-forge AGENTS.md before sync overwrites it
if [ -f "$TARGET/AGENTS.md" ] && ! grep -q "Workflow discipline for Claude Code" "$TARGET/AGENTS.md" 2>/dev/null; then
  cp "$TARGET/AGENTS.md" "$TARGET/AGENTS.md.pre-forge.bak"
  echo "  ! backed up existing AGENTS.md -> AGENTS.md.pre-forge.bak"
fi

# --- GENERATE engine dirs + AGENTS.md + opencode.json via sync (no symlinks) ---
bash "$TARGET/sync.sh" >/dev/null

# --- .gitignore (merge, don't clobber): generated engine artifacts + local state ---
touch "$TARGET/.gitignore"
if ! grep -qx '# forge-ai (generated — regenerate with ./sync.sh)' "$TARGET/.gitignore"; then
  {
    printf '\n# forge-ai (generated — regenerate with ./sync.sh)\n'
    printf '.claude/\n.agents/\n.codex/\n/AGENTS.md\n/opencode.json\n'
    printf '\n# forge-ai (local state)\n.DS_Store\n.workflow/\n'
  } >> "$TARGET/.gitignore"
fi

# --- warn if a project-owned config lacks the forge push/PR gate ---
warn_gate() {  # $1 = configs/ file, $2 = grep needle, $3 = hint
  if [ -f "$TARGET/$1" ] && ! grep -q "$2" "$TARGET/$1" 2>/dev/null; then
    echo "  ! $1 has no forge push/PR gate ($3) — add it, then re-run ./sync.sh."
  fi
}
warn_gate "configs/claude/settings.json" "git push"       "ask-tier on git push / gh pr create"
warn_gate "configs/codex/config.toml"    "approval_policy" "approval_policy"
warn_gate "configs/opencode.json"        "git push"       "permission.bash git push* / gh pr create*"

# --- post-install validation: generated skill copies + AGENTS.md must exist ---
ok=1
for p in .claude/skills .agents/skills; do
  [ -e "$TARGET/$p/new-feature/SKILL.md" ] || { echo "  ! discovery FAILED: $p was not generated"; ok=0; }
done
[ -f "$TARGET/AGENTS.md" ] || { echo "  ! AGENTS.md was not generated"; ok=0; }
if [ "$ok" = 1 ]; then
  echo "  ✓ validation: skill-discovery paths (.claude + .agents) + AGENTS.md generated"
else
  echo "  ✗ validation found issues above — fix before relying on forge-ai here"
fi

echo "forge-ai installed."
echo "  next: (1) fill PROJECT.md   (2) in Codex, trust the project when prompted"
echo "        (3) open the project in any of Claude Code / Codex / OpenCode"
echo "  edit the neutral source (skills/, configs/, CLAUDE.md), then re-run ./sync.sh"
echo "  (or sync.ps1 on Windows) to regenerate. Generated engine dirs are gitignored."
