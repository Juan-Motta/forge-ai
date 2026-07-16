# Continuity — session handoff

> The first thing to read on a new session (auto-loaded via `CLAUDE.md` / `AGENTS.md`).
> Keep it current; refresh it with the `checkpoint` skill before closing a session.

- **Focus:** Building out forge-ai itself — interoperable workflow discipline (Claude Code, Codex, OpenCode), skills + config only, no scripts/hooks.
- **Next step:** Council substantive findings (1)-(6) are now DONE (gate profiles, single-engine fallback, finish-branch reorder, read-only reviewers, install validation+gate-warn, Windows note). Remaining, all manual/verification: (a) test the native push/PR prompt interactively in each engine; (b) verify the exact read-only flag for `claude -p` and the `opencode` read-only path; (c) smoke-test the `models.md` CLI invocation strings end-to-end; (d) couldn't exercise install.sh's config-gate-warn via Bash (safety hook blocks touching .claude/settings.json) — logic verified by inspection, run it manually once.
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
