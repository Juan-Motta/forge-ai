# Continuity — session handoff

> The first thing to read on a new session (auto-loaded via `CLAUDE.md` / `AGENTS.md`).
> Keep it current; refresh it with the `checkpoint` skill before closing a session.

- **Focus:** Building out forge-ai itself — interoperable workflow discipline (Claude Code, Codex, OpenCode), skills + config only, no scripts/hooks.
- **Next step:** Address the council's substantive findings (cheap/factual ones already applied): (1) single-engine review path (cross-engine gate is unsatisfiable for solo-CLI users), (2) per-workflow gate profiles (quick-fix/fix-bug can't meet the universal gate), (3) fix finish-branch ordering (record changelog/memory BEFORE the ship commit), (4) invoke reviewers read-only, (5) make install.sh propagate/validate gates for already-configured projects, (6) Windows symlink note. Also still pending: manual test of the native push/PR prompt in each engine.
- **Blockers:** none
- **Active workflow:** none
- **Updated:** 2026-07-15

## Handoff notes

Tier A is essentially complete: 10 skills (prd, research, plan, new-feature, fix-bug,
quick-fix, review, council, finish-branch, checkpoint) + 9 rules, docs layout scaffolded,
memory + continuity disciplines in place. Enforcement is advisory + native coarse approval
on push/PR (`.claude/settings.json`, `.codex/config.toml`, `opencode.json`). Hard
conditional blocking (hooks) is deferred as Tier C. Never use worktrees — simple branch.

Live discovery validated 2026-07-15 on all 3 engines (Claude Code, Codex, OpenCode):
instructions auto-load, all 10 skills discovered via symlink, CONTINUITY.md read — all
pass. Still unverified: the native push/PR gate (needs an interactive test).
