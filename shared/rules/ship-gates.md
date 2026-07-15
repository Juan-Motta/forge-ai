# Ship Gates

Before any outward action — `git commit`, `git push`, `gh pr create` — the required
boxes in `.workflow/state.md` must be checked:

- [ ] On a feature branch (not `main`)
- [ ] Plan written and design-reviewed by the other engine
- [ ] Tests written (TDD) and passing
- [ ] Code review clean (no open P0/P1/P2 — see `severity.md`)
- [ ] Change verified by actually exercising it
- [ ] `.workflow/state.md` updated

## How enforcement works here (advisory + native coarse gate)

There is **no hook** that conditionally blocks a commit when a box is unchecked. Two
things stand in:

1. **Advisory (both engines):** you are instructed — here and in the workflow skill —
   not to ship until the boxes pass. Honor it.
2. **Native coarse gate (per harness):** outward actions prompt for human approval
   regardless of gate state:
   - **Claude Code** — `git push` and `gh pr create` are `ask`-tier in
     `.claude/settings.json`.
   - **Codex CLI** — `approval_policy` in `.codex/config.toml` pauses for approval before
     non-trivial shell commands.

The native gate does not read `.workflow/state.md`; it always asks. The human approver is
the backstop: **do not approve a push/PR whose gates are not green.**

> A later phase can replace the advisory layer with hook-based conditional blocking
> (deny when a box is unchecked). That needs harness hooks/scripts, deliberately out of
> scope for this build. See `docs/`.
