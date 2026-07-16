# Ship Gates

Which boxes are required before an outward action (`git commit`, `git push`,
`gh pr create`) depends on the **gate profile** of the active workflow. The skill records
its profile in `.workflow/state.md`; `finish-branch` validates the active profile before
shipping.

## Gate profiles

### `standard` — used by `new-feature`, `fix-bug`

- [ ] On a feature branch (not `main`)
- [ ] Plan written and design-reviewed (cross-engine — see single-engine fallback below).
      **`N/A: <reason>` is allowed for a simple `fix-bug`** (1–2 files, not a high-impact
      surface) — the failing test + code review still apply. `new-feature` and high-impact
      fixes always require it.
- [ ] Tests written (TDD) and passing
- [ ] Code review clean — no open P0/P1/P2 (`severity.md`), cross-engine
- [ ] Change verified by actually exercising it
- [ ] `.workflow/state.md` updated

The active workflow records its profile in `.workflow/state.md` (the **Profile** field —
see `state.template.md`); `finish-branch` validates that profile's boxes before shipping.

### `light` — used by `quick-fix`

- [ ] On a feature branch (not `main`)
- [ ] Change verified (ran it, or the relevant test passes)
- [ ] Still trivial (<3 files, no behavior risk) — otherwise **escalate** to `new-feature`/`fix-bug` and switch to the `standard` profile

### No gate — `prd`, `research`, `plan`, `index`, `checkpoint`, `review`, `council`

These produce an artifact or advice and don't ship on their own; they feed a workflow that
carries one of the profiles above.

## Single-engine fallback (the cross-engine review items)

The `standard` profile's review items assume **≥2 engines are available**. Most users run
one CLI, so this must degrade honestly instead of becoming unsatisfiable:

If no second engine is available, satisfy the review items by either:
- a **delayed self-review** — step away, then re-read the plan/diff fresh against
  `severity.md` as if it were someone else's; or
- a **human reviewer**.

Then log a waiver in `.workflow/state.md`, e.g.:
`Review: single-engine self-review (no second engine available) — <date>`

Cross-engine review is the default and preferred (real model diversity). The waiver just
makes the degradation **explicit and auditable**, never silent.

## How enforcement works here (advisory + a best-effort native prompt)

**Be honest about what this is: discipline, not a hard gate.** Nothing conditionally
blocks a commit when a box is unchecked. Two things stand in — both advisory:

1. **Advisory (all engines):** you are instructed — here and in the workflow skill — not
   to ship until the profile's boxes pass. Honor it.
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
