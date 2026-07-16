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

# --- 1. bash install: correct paths, no framework leak, AGENTS.md == CLAUDE.md ---
TB="$TMP/bash"; mkdir -p "$TB"
"$ROOT/install.sh" "$TB" >/dev/null || fail "install.sh exited non-zero"
for f in CLAUDE.md .claude/skills/new-feature/SKILL.md .agents/skills/new-feature/SKILL.md \
         .claude/settings.json .codex/config.toml opencode.json AGENTS.md; do
  [ -e "$TB/$f" ] || fail "bash: expected $f was not generated"
done
for f in install.sh install.ps1 README.md LICENSE src; do
  [ -e "$TB/$f" ] && fail "bash: framework file leaked into target: $f"
done
diff -q "$TB/AGENTS.md" "$TB/CLAUDE.md" >/dev/null || fail "AGENTS.md does not match CLAUDE.md"
echo "ok: bash install (paths, no leak, AGENTS.md mirror)"

# --- 2. pwsh install (if available) must be byte-identical to bash ---
if command -v pwsh >/dev/null 2>&1; then
  TP="$TMP/ps"; mkdir -p "$TP"
  pwsh -NoProfile -File "$ROOT/install.ps1" "$TP" >/dev/null || fail "install.ps1 exited non-zero"
  diff -rq "$TB" "$TP" >/dev/null || fail "bash and pwsh targets differ (install/sync parity broken)"
  echo "ok: pwsh install + parity with bash"
else
  echo "skip: pwsh not installed — parity check skipped"
fi

# --- 3. --upgrade preserves project-owned files and custom skills ---
printf 'MYPROJECT_MARKER\n' > "$TB/PROJECT.md"
mkdir -p "$TB/skills/my-skill"; printf 'mine\n' > "$TB/skills/my-skill/SKILL.md"
"$ROOT/install.sh" "$TB" --upgrade >/dev/null || fail "install --upgrade exited non-zero"
grep -q MYPROJECT_MARKER "$TB/PROJECT.md" || fail "upgrade clobbered project-owned PROJECT.md"
[ -f "$TB/skills/my-skill/SKILL.md" ] || fail "upgrade dropped a custom skill from skills/"
[ -f "$TB/.agents/skills/my-skill/SKILL.md" ] || fail "upgrade did not regenerate custom skill into .agents"
echo "ok: --upgrade preserves project-owned files + custom skills"

# --- 4. data-loss guard: a user's own new-feature skill is backed up, not wiped ---
TG="$TMP/guard"; mkdir -p "$TG/.claude/skills/new-feature"
printf 'USER_CUSTOM_MARKER\n' > "$TG/.claude/skills/new-feature/SKILL.md"
"$ROOT/install.sh" "$TG" >/dev/null || fail "guard-case install exited non-zero"
grep -q USER_CUSTOM_MARKER "$TG/.claude/skills.pre-forge.bak/new-feature/SKILL.md" \
  || fail "user's own new-feature skill was not backed up (data loss)"
echo "ok: data-loss guard backs up a user's own skills"

# --- 5. sync fails (non-zero) on missing required input ---
FS="$TMP/syncfail"; mkdir -p "$FS/skills/x"; printf -- '---\n' > "$FS/skills/x/SKILL.md"
cp "$ROOT/src/sync.sh" "$FS/"
if bash "$FS/sync.sh" >/dev/null 2>&1; then fail "sync.sh should fail without CLAUDE.md but exited 0"; fi
[ -e "$FS/AGENTS.md" ] && fail "sync.sh produced output despite missing CLAUDE.md"
echo "ok: sync fails non-zero on missing input"

# --- 6. --upgrade prunes framework files removed upstream, keeps project-owned ones ---
# Simulate a framework skill that existed at a prior install (in the manifest) but was
# dropped upstream (not in payload); and a project skill (never in the manifest).
printf 'skill:ghost\n' >> "$TB/.forge-manifest"
mkdir -p "$TB/skills/ghost";   printf -- '---\nname: ghost\n---\n'   > "$TB/skills/ghost/SKILL.md"
mkdir -p "$TB/skills/keep-me"; printf -- '---\nname: keep-me\n---\n' > "$TB/skills/keep-me/SKILL.md"
"$ROOT/install.sh" "$TB" --upgrade >/dev/null || fail "prune-case upgrade exited non-zero"
[ -e "$TB/skills/ghost" ] && fail "framework skill removed upstream was not pruned"
[ -e "$TB/skills/keep-me/SKILL.md" ] || fail "project skill was wrongly pruned"
echo "ok: --upgrade prunes upstream-removed framework files, keeps project files"

echo "ALL PASS"
