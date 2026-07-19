#!/usr/bin/env bash
#
# forge-ai installer — copy the workflow discipline into a target project.
#
#   ./install.sh [target-dir] [--upgrade]
#
# With no target-dir, installs into the current working directory. So the common flow is:
#   cd my-project && /path/to/forge-ai/install.sh
#
# THIN INSTALL: the target receives only what the agent needs at RUNTIME. All framework
# machinery (the neutral source in ./src/, the generators sync.sh/ps1, the generation
# inputs in configs/, and the seed templates) stays in the forge-ai repo — never copied
# into the target. To customize or upgrade, edit the forge-ai source and re-run this
# installer against the target (`--upgrade`, or a bare re-run from inside the project).
#
# The shippable payload is the NEUTRAL source in ./src/ (CLAUDE.md, skills/, shared/,
# configs/, docs/, *.template.md). This installer copies the runtime subset into the
# target, then runs `sync.sh --out <target>` to GENERATE each engine's config + skills
# (.claude/ + .agents/skills + .codex/config.toml + AGENTS.md + opencode.json) straight
# into the target. No symlinks (Windows-safe). The generated engine artifacts are COMMITTED
# with the target project so a fresh clone works immediately — no forge-ai dependency at
# runtime; re-run the installer after editing the source to regenerate.
#
# LANDS IN THE TARGET (runtime only):
#   CLAUDE.md, AGENTS.md, opencode.json, .claude/, .agents/, .codex/ (generated),
#   shared/rules/*.md + shared/state.template.md + shared/scripts/* (managed), docs/ scaffolding + CHANGELOG,
#   PROJECT.md + CONTINUITY.md (project-owned, seeded if missing).
# STAYS IN forge-ai (never copied): src/skills (neutral), configs/, sync.sh, sync.ps1,
#   *.template.md, docs/extending.md.
#
# MANAGED (framework baseline — OVERWRITTEN on install/upgrade): CLAUDE.md, the framework's
#   OWN entries in shared/rules/, shared/state.template.md. Your own rules dropped into
#   shared/rules/ survive upgrades (selective, per-entry by name).
# PROJECT-OWNED (created only if missing — NEVER clobbered): PROJECT.md, CONTINUITY.md,
#   docs/CHANGELOG.md. Per-project Claude overrides go in .claude/settings.local.json.
#
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SRC/src"
MODE="install"
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --upgrade) MODE="upgrade" ;;
    -*)        echo "usage: $0 [target-dir] [--upgrade]  (unknown arg: $1)" >&2; exit 2 ;;
    *)         if [ -z "$TARGET" ]; then TARGET="$1"; else echo "usage: $0 [target-dir] [--upgrade]  (unexpected arg: $1)" >&2; exit 2; fi ;;
  esac
  shift
done
TARGET="${TARGET:-$PWD}"

[ -d "$TARGET" ] || { echo "error: target dir not found: $TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"
{ [ -f "$PAYLOAD/CLAUDE.md" ] && [ -d "$PAYLOAD/skills" ]; } || { echo "error: payload not found — run this from the forge-ai repo" >&2; exit 2; }
[ "$TARGET" != "$SRC" ]     || { echo "error: refusing to install into forge-ai itself" >&2; exit 2; }
[ "$TARGET" != "$PAYLOAD" ] || { echo "error: refusing to install into the forge-ai payload dir (src/)" >&2; exit 2; }

echo "forge-ai → installing into: $TARGET  (mode: $MODE)"

# --- self-healing: drop machinery this version no longer installs into the target ---
# (thin model — machinery lives in the forge-ai repo; the target gets runtime only.) This
# migrates a target from an older, bloated install. Gated on a prior forge install
# (.forge-manifest present) so a FIRST install never touches an unrelated project's own
# configs/ or skills/ dirs.
if [ -f "$TARGET/.forge-manifest" ]; then
  # Framework-owned, no user content — removed outright.
  for f in sync.sh sync.ps1 state.template.md PROJECT.template.md CONTINUITY.template.md docs/extending.md; do
    [ -e "$TARGET/$f" ] && { rm -f "$TARGET/$f"; echo "  - removed obsolete framework file: $f"; }
  done
  # configs/ and the neutral skills/ may hold pre-forge user edits under the old model —
  # back them up rather than delete, so nothing is lost during migration.
  if [ -d "$TARGET/configs" ]; then
    rm -rf "$TARGET/configs.pre-forge.bak"; mv "$TARGET/configs" "$TARGET/configs.pre-forge.bak"
    echo "  ! configs/ is obsolete (engine configs are generated now) -> configs.pre-forge.bak; per-project Claude tweaks go in .claude/settings.local.json"
  fi
  if [ -d "$TARGET/skills" ]; then
    rm -rf "$TARGET/skills.pre-forge.bak"; mv "$TARGET/skills" "$TARGET/skills.pre-forge.bak"
    echo "  ! neutral skills/ is obsolete (skills are generated now) -> skills.pre-forge.bak; add custom skills to the forge-ai repo"
  fi
fi

# --- MANAGED: CLAUDE.md (back up a pre-existing, non-forge one on first install) ---
if [ -f "$TARGET/CLAUDE.md" ] && ! grep -q "Workflow discipline for Claude Code" "$TARGET/CLAUDE.md" 2>/dev/null; then
  cp "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.md.pre-forge.bak"
  echo "  ! backed up existing CLAUDE.md -> CLAUDE.md.pre-forge.bak (move project-specifics into PROJECT.md)"
fi
cp "$PAYLOAD/CLAUDE.md" "$TARGET/CLAUDE.md"

# --- MANAGED: framework shared/rules/ (per-entry overwrite by name) ---
# Refresh only the framework's own rule entries; anything else in shared/rules/ (your
# project's own rules) is left untouched, so it survives --upgrade.
mkdir -p "$TARGET/shared/rules"
new_rules="$(cd "$PAYLOAD/shared/rules" && ls *.md 2>/dev/null)"

# Prune framework rules removed upstream: anything in the last-install manifest that is no
# longer in the current payload is a framework rule deleted upstream — remove it. Project-owned
# rules are never in the manifest, so they are untouched. (No manifest yet = skip prune.)
manifest="$TARGET/.forge-manifest"
if [ -f "$manifest" ]; then
  while IFS= read -r line; do
    case "$line" in
      rule:*) n="${line#rule:}"; printf '%s\n' "$new_rules" | grep -qxF "$n" || { rm -f "$TARGET/shared/rules/$n"; echo "  - pruned framework rule removed upstream: $n"; } ;;
    esac
  done < "$manifest"
fi

for f in "$PAYLOAD"/shared/rules/*.md; do
  cp "$f" "$TARGET/shared/rules/$(basename "$f")"
done

# Record the framework-owned manifest for the next upgrade's prune (rules only; skills are
# fully generated by sync, so there is nothing skill-level to selectively prune).
{ printf '%s\n' "$new_rules" | sed 's/^/rule:/'; } > "$manifest"

# --- MANAGED: workflow state template (lives in shared/, copied to .workflow/state.md at
#     workflow start by the skills) ---
cp "$PAYLOAD/shared/state.template.md" "$TARGET/shared/state.template.md"

# --- MANAGED: framework shared/scripts/ (agent-invoked Tier-B helpers, e.g. check-gates) ---
if [ -d "$PAYLOAD/shared/scripts" ]; then
  mkdir -p "$TARGET/shared/scripts"
  for f in "$PAYLOAD"/shared/scripts/*; do
    [ -e "$f" ] || continue
    cp "$f" "$TARGET/shared/scripts/$(basename "$f")"
  done
  chmod +x "$TARGET"/shared/scripts/*.sh 2>/dev/null || true
fi

# --- MANAGED: docs/ scaffolding ---
mkdir -p "$TARGET/docs"
for d in prds plans research solutions adr; do
  mkdir -p "$TARGET/docs/$d"
  [ -e "$TARGET/docs/$d/.gitkeep" ] || touch "$TARGET/docs/$d/.gitkeep"
done

# --- PROJECT-OWNED: PROJECT.md / CONTINUITY.md / docs/CHANGELOG.md (create only if missing) ---
[ -f "$TARGET/PROJECT.md" ]    || { cp "$PAYLOAD/PROJECT.template.md" "$TARGET/PROJECT.md"; echo "  + created PROJECT.md (fill in persona/info/variables/special rules)"; }
[ -f "$TARGET/CONTINUITY.md" ] || cp "$PAYLOAD/CONTINUITY.template.md" "$TARGET/CONTINUITY.md"
[ -f "$TARGET/docs/CHANGELOG.md" ] || cp "$PAYLOAD/docs/CHANGELOG.md" "$TARGET/docs/CHANGELOG.md"

# --- back up any pre-existing, NON-forge per-engine skills dir before sync overwrites it ---
# (forge-generated dirs carry a .forge-generated marker; a dir without it is the user's own,
#  so we never wipe a user's skills — even one coincidentally named new-feature.)
for eng in .claude .agents; do
  sd="$TARGET/$eng/skills"
  if [ -e "$sd" ] && [ ! -e "$sd/.forge-generated" ]; then
    mv "$sd" "$sd.pre-forge.bak"
    echo "  ! backed up existing $eng/skills -> $eng/skills.pre-forge.bak (add custom skills to the forge-ai repo)"
  fi
done
# back up a real, non-forge AGENTS.md before sync overwrites it
if [ -f "$TARGET/AGENTS.md" ] && ! grep -q "Workflow discipline for Claude Code" "$TARGET/AGENTS.md" 2>/dev/null; then
  cp "$TARGET/AGENTS.md" "$TARGET/AGENTS.md.pre-forge.bak"
  echo "  ! backed up existing AGENTS.md -> AGENTS.md.pre-forge.bak"
fi

# --- GENERATE engine dirs + AGENTS.md + opencode.json via sync (reads the forge-ai source,
#     writes straight into the target — no source or sync script copied there) ---
bash "$PAYLOAD/sync.sh" --out "$TARGET" >/dev/null

# --- .gitignore (merge, don't clobber): ONLY local state ---
# The generated engine artifacts (.claude/, .agents/, .codex/, AGENTS.md, opencode.json)
# are COMMITTED with the project so a fresh clone works immediately — no post-clone step,
# no dependency on forge-ai. Only genuinely local/transient state is ignored here.
touch "$TARGET/.gitignore"
if ! grep -qx '# forge-ai (local state — do not commit)' "$TARGET/.gitignore"; then
  {
    printf '\n# forge-ai (local state — do not commit)\n'
    printf '.DS_Store\n.workflow/\n.claude/settings.local.json\n'
  } >> "$TARGET/.gitignore"
fi

# --- warn if the generated config lacks the forge push/PR gate (points at the forge-ai
#     source baseline that produced it) ---
warn_gate() {  # $1 = generated file in target, $2 = grep needle, $3 = hint
  if [ -f "$TARGET/$1" ] && ! grep -q "$2" "$TARGET/$1" 2>/dev/null; then
    echo "  ! $1 has no forge push/PR gate ($3) — add it to the forge-ai source, then re-run."
  fi
}
warn_gate ".claude/settings.json" "git push"       "ask-tier on git push / gh pr create"
warn_gate ".codex/config.toml"    "approval_policy" "approval_policy"
warn_gate "opencode.json"         "git push"       "permission.bash git push* / gh pr create*"

# --- post-install validation: generated skills + AGENTS.md + engine configs must exist ---
ok=1
for p in .claude/skills .agents/skills; do
  [ -e "$TARGET/$p/new-feature/SKILL.md" ] || { echo "  ! discovery FAILED: $p was not generated"; ok=0; }
done
for f in AGENTS.md .claude/settings.json .codex/config.toml opencode.json shared/state.template.md; do
  [ -f "$TARGET/$f" ] || { echo "  ! FAILED: $f was not generated"; ok=0; }
done
if [ "$ok" != 1 ]; then
  echo "  ✗ install INCOMPLETE — issues above; NOT marking as installed" >&2
  exit 1
fi
echo "  ✓ validation: skills (.claude + .agents), AGENTS.md, and engine configs generated"

echo "forge-ai installed."
echo "  next: (1) fill PROJECT.md   (2) in Codex, trust the project when prompted"
echo "        (3) open the project in any of Claude Code / Codex / OpenCode"
echo "  to customize or upgrade: edit the forge-ai source, then re-run this installer"
echo "  against the project (--upgrade, or a bare re-run from inside it)."
