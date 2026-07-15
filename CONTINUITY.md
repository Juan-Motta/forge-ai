# Continuity — session handoff

> The first thing to read on a new session (auto-loaded via `CLAUDE.md` / `AGENTS.md`).
> Keep it current; refresh it with the `checkpoint` skill before closing a session.

- **Focus:** Building out forge-ai itself — interoperable workflow discipline (Claude Code, Codex, OpenCode), skills + config only, no scripts/hooks.
- **Next step:** Decide the next capability to add (Tier A: more skills/rules; or move to Tier B scripts). Live-test that each engine actually discovers the symlinked skills + `AGENTS.md`.
- **Blockers:** none
- **Active workflow:** none
- **Updated:** 2026-07-15

## Handoff notes

Tier A is essentially complete: 10 skills (prd, research, plan, new-feature, fix-bug,
quick-fix, review, council, finish-branch, checkpoint) + 9 rules, docs layout scaffolded,
memory + continuity disciplines in place. Enforcement is advisory + native coarse approval
on push/PR (`.claude/settings.json`, `.codex/config.toml`, `opencode.json`). Hard
conditional blocking (hooks) is deferred as Tier C. Never use worktrees — simple branch.
