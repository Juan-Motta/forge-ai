# Continuity — session handoff

> The first thing to read on a new session (auto-loaded via `CLAUDE.md` / `AGENTS.md`).
> Keep it current; refresh it with the `checkpoint` skill before closing a session.

- **Focus:** Building out forge-ai itself — interoperable workflow discipline (Claude Code, Codex, OpenCode), skills + config only, no scripts/hooks.
- **Next step:** Manually test the native push/PR approval gate in each engine (headless can't exercise the approval prompt): open each CLI in the repo, attempt `git push`, confirm it asks/pauses. Then pick the next capability (Tier B validator script, or Tier C hooks).
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
