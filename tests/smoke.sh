#!/usr/bin/env bash
#
# forge-ai smoke test — install into throwaway targets and assert the result.
# Backs the README's "validated on bash and PowerShell" claim and guards install/sync
# parity. Framework dev tool — NOT payload, never installed into a target.
#
#   ./tests/smoke.sh
#
# Exits 0 with "ALL PASS", or non-zero on the first failed assertion.
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# --- 1. bash install: thin runtime payload, no machinery leak, AGENTS.md == CLAUDE.md ---
TB="$TMP/bash"; mkdir -p "$TB"
"$ROOT/install.sh" "$TB" >/dev/null || fail "install.sh exited non-zero"
# runtime files the agent needs must be present
for f in CLAUDE.md AGENTS.md opencode.json PROJECT.md CONTINUITY.md \
         .claude/skills/new-feature/SKILL.md .agents/skills/new-feature/SKILL.md \
         .claude/settings.json .codex/config.toml docs/CHANGELOG.md \
         shared/state.template.md; do
  [ -e "$TB/$f" ] || fail "bash: expected runtime file $f was not produced"
done
ls "$TB"/shared/rules/*.md >/dev/null 2>&1 || fail "bash: shared/rules/*.md missing"
# framework machinery + repo files must NOT land in the target (thin install)
for f in install.sh install.ps1 README.md LICENSE src \
         skills configs sync.sh sync.ps1 \
         state.template.md PROJECT.template.md CONTINUITY.template.md docs/extending.md; do
  [ -e "$TB/$f" ] && fail "bash: framework file leaked into target: $f"
done
diff -q "$TB/AGENTS.md" "$TB/CLAUDE.md" >/dev/null || fail "AGENTS.md does not match CLAUDE.md"
echo "ok: bash install (thin payload, no machinery leak, AGENTS.md mirror)"

# --- 2. pwsh install (if available) must be byte-identical to bash ---
if command -v pwsh >/dev/null 2>&1; then
  TP="$TMP/ps"; mkdir -p "$TP"
  pwsh -NoProfile -File "$ROOT/install.ps1" "$TP" >/dev/null || fail "install.ps1 exited non-zero"
  diff -rq "$TB" "$TP" >/dev/null || fail "bash and pwsh targets differ (install/sync parity broken)"
  echo "ok: pwsh install + parity with bash"
else
  echo "skip: pwsh not installed — parity check skipped"
fi

# --- 3. --upgrade preserves project-owned files and project-owned rules ---
printf 'MYPROJECT_MARKER\n' > "$TB/PROJECT.md"
printf 'mine\n' > "$TB/shared/rules/my-rule.md"
"$ROOT/install.sh" "$TB" --upgrade >/dev/null || fail "install --upgrade exited non-zero"
grep -q MYPROJECT_MARKER "$TB/PROJECT.md" || fail "upgrade clobbered project-owned PROJECT.md"
[ -f "$TB/shared/rules/my-rule.md" ] || fail "upgrade dropped a project-owned rule from shared/rules/"
echo "ok: --upgrade preserves project-owned files + project rules"

# --- 4. data-loss guard: a user's own new-feature skill is backed up, not wiped ---
TG="$TMP/guard"; mkdir -p "$TG/.claude/skills/new-feature"
printf 'USER_CUSTOM_MARKER\n' > "$TG/.claude/skills/new-feature/SKILL.md"
"$ROOT/install.sh" "$TG" >/dev/null || fail "guard-case install exited non-zero"
grep -q USER_CUSTOM_MARKER "$TG/.claude/skills.pre-forge.bak/new-feature/SKILL.md" \
  || fail "user's own new-feature skill was not backed up (data loss)"
echo "ok: data-loss guard backs up a user's own skills"

# --- 5. sync fails (non-zero) on missing input; --out generates into a separate dir ---
FS="$TMP/syncfail"; mkdir -p "$FS/skills/x"; printf -- '---\n' > "$FS/skills/x/SKILL.md"
cp "$ROOT/src/sync.sh" "$FS/"
if bash "$FS/sync.sh" >/dev/null 2>&1; then fail "sync.sh should fail without CLAUDE.md but exited 0"; fi
[ -e "$FS/AGENTS.md" ] && fail "sync.sh produced output despite missing CLAUDE.md"
SO="$TMP/syncout"; mkdir -p "$SO"
bash "$ROOT/src/sync.sh" --out "$SO" >/dev/null || fail "sync.sh --out exited non-zero"
[ -f "$SO/AGENTS.md" ] || fail "sync.sh --out did not generate AGENTS.md into the out dir"
[ -f "$ROOT/src/AGENTS.md" ] && fail "sync.sh --out wrote into the source instead of the out dir"
echo "ok: sync fails non-zero on missing input; --out targets a separate dir"

# --- 6. --upgrade prunes framework rules removed upstream, keeps project-owned ones ---
printf 'rule:ghost.md\n' >> "$TB/.forge-manifest"
printf 'ghost\n'   > "$TB/shared/rules/ghost.md"
printf 'keep-me\n' > "$TB/shared/rules/keep-me.md"
"$ROOT/install.sh" "$TB" --upgrade >/dev/null || fail "prune-case upgrade exited non-zero"
[ -e "$TB/shared/rules/ghost.md" ] && fail "framework rule removed upstream was not pruned"
[ -e "$TB/shared/rules/keep-me.md" ] || fail "project rule was wrongly pruned"
echo "ok: --upgrade prunes upstream-removed framework rules, keeps project rules"

# --- 7. bare run installs into cwd; running from inside forge-ai is refused ---
TC="$TMP/cwd"; mkdir -p "$TC"
( cd "$TC" && "$ROOT/install.sh" >/dev/null ) || fail "bare install into cwd exited non-zero"
[ -f "$TC/CLAUDE.md" ] || fail "bare run did not install into the current directory"
if ( cd "$ROOT"     && "$ROOT/install.sh" >/dev/null 2>&1 ); then fail "self-install from forge-ai root should be refused"; fi
if ( cd "$ROOT/src" && "$ROOT/install.sh" >/dev/null 2>&1 ); then fail "install into the payload dir (src) should be refused"; fi
echo "ok: bare run targets cwd; self-install into forge-ai/src is refused"

# --- 8. migration self-heal: an older bloated install is cleaned up on upgrade ---
TM="$TMP/migrate"; mkdir -p "$TM"
"$ROOT/install.sh" "$TM" >/dev/null || fail "migration-base install exited non-zero"
# simulate leftovers from an older, non-thin install
touch "$TM/sync.sh" "$TM/sync.ps1" "$TM/state.template.md" "$TM/PROJECT.template.md" "$TM/CONTINUITY.template.md"
mkdir -p "$TM/docs"; touch "$TM/docs/extending.md"
mkdir -p "$TM/configs/claude"; printf 'old\n' > "$TM/configs/claude/settings.json"
mkdir -p "$TM/skills/old-skill"; printf 'old\n' > "$TM/skills/old-skill/SKILL.md"
"$ROOT/install.sh" "$TM" --upgrade >/dev/null || fail "migration upgrade exited non-zero"
for f in sync.sh sync.ps1 state.template.md PROJECT.template.md CONTINUITY.template.md docs/extending.md; do
  [ -e "$TM/$f" ] && fail "migration did not remove obsolete framework file: $f"
done
[ -e "$TM/configs" ] && fail "migration did not move obsolete configs/ aside"
[ -f "$TM/configs.pre-forge.bak/claude/settings.json" ] || fail "migration lost configs/ content (no backup)"
[ -e "$TM/skills" ] && fail "migration did not move obsolete neutral skills/ aside"
[ -f "$TM/skills.pre-forge.bak/old-skill/SKILL.md" ] || fail "migration lost skills/ content (no backup)"
echo "ok: migration self-heal removes machinery, backs up user content"

# --- 9. first install (no prior forge install) leaves an unrelated project's own dirs alone ---
TF="$TMP/first"; mkdir -p "$TF/configs" "$TF/skills/mine"
printf 'mine\n' > "$TF/configs/mine.txt"; printf 'mine\n' > "$TF/skills/mine/SKILL.md"
"$ROOT/install.sh" "$TF" >/dev/null || fail "first-install-with-own-dirs exited non-zero"
[ -f "$TF/configs/mine.txt" ] || fail "first install clobbered an unrelated project's configs/"
[ -f "$TF/skills/mine/SKILL.md" ] || fail "first install clobbered an unrelated project's skills/"
[ -e "$TF/configs.pre-forge.bak" ] && fail "first install wrongly backed up an unrelated configs/ (self-heal not gated)"
echo "ok: first install leaves an unrelated project's own configs/ and skills/ untouched"

echo "ALL PASS"
