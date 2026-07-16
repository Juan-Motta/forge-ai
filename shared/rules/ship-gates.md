# Ship Gates

Before any outward action — `git commit`, `git push`, `gh pr create` — the required
boxes in `.workflow/state.md` must be checked:

- [ ] On a feature branch (not `main`)
- [ ] Plan written and design-reviewed by the other engine
- [ ] Tests written (TDD) and passing
- [ ] Code review clean (no open P0/P1/P2 — see `severity.md`)
- [ ] Change verified by actually exercising it
- [ ] `.workflow/state.md` updated

## How enforcement works here (advisory + a best-effort native prompt)

**Be honest about what this is: discipline, not a hard gate.** Nothing conditionally
blocks a commit when a box is unchecked. Two things stand in — both advisory:

1. **Advisory (all engines):** you are instructed — here and in the workflow skill — not
   to ship until the boxes pass. Honor it.
2. **Best-effort native prompt (per engine):** each engine can prompt for human approval
   on outward commands — but it reads **no** gate state and matches commands by pattern,
   so it is bypassable (e.g. `git -C . push`, a PR via API, another tool):
   - **Claude Code** — `git push` / `gh pr create` are `ask`-tier in `.claude/settings.json`.
   - **Codex** — `approval_policy` in `.codex/config.toml` asks when a command crosses the
     sandbox boundary (not before every command).
   - **OpenCode** — `permission.bash` in `opencode.json` sets `git push*` / `gh pr create*`
     to `ask` (force-push `deny`).

The prompt shows the human a generic "allow this command?", **not** the checklist — so it
is a commit-confirmation, not proof the gates are green. The approver must
**independently check `.workflow/state.md` before approving.**

> A later phase can replace the advisory layer with hook-based conditional blocking
> (deny when a box is unchecked). That needs harness hooks/scripts, deliberately out of
> scope for this build. See `docs/`.
