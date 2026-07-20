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
- [ ] E2E verified via verify-e2e (report: docs/e2e/reports/<...>.md) — `N/A: <reason>` allowed for purely internal changes (migration, refactor, tooling) and UI-only changes (no v1 adapter)
- [ ] `.workflow/state.md` updated

> The `E2E verified` box is an **Attested** signal: it asserts that a verify-e2e run
> produced a `VERDICT: PASS` report committed under `docs/e2e/reports/`. `check-gates`
> binds the box to that artifact, but the report is still the agent's own output — it is
> not the Verified tier (which requires an out-of-turn recompute in CI). See the
> Verified / Attested / Advisory ladder below.

#### E2E evidence binding

When the `E2E verified` box is checked as a **real run** (not an `— N/A:` escape), it must
carry the concrete report path it produced:

`- [x] E2E verified via verify-e2e (report: docs/e2e/reports/<file>.md)`

`check-gates` validates the report **named in the box** — not just "any report in the
directory". For the checked box it requires that named path to:

1. **be concrete** — the `(report: …)` path is present and is not the `<...>` placeholder
   (a checked box that still names the placeholder fails);
2. **exist** — resolved against the git toplevel, not the current directory;
3. **carry a top-level `VERDICT: PASS`** — the *first* `VERDICT:` line must be exactly
   `VERDICT: PASS` (a per-UC `PASS` under a top-level `FAIL`, or `VERDICT: PASS extra`, fails);
4. **be fresh on this branch** — the path must be new work (committed since the branch
   point, staged, an unstaged tracked edit, or untracked).

The branch **base is auto-detected** by the *closest* merge-base among
`dev`, `main`, `master`, and their `origin/…` counterparts (plus `origin/HEAD`), so it
works whether the repo integrates on `dev` or `main`. Freshness is **best-effort**: if no
base ref resolves (single-branch or detached HEAD), freshness is skipped **with a note to
stderr** — but existence + top-level `PASS` are *always* required. A checked box can never
pass the gate without its named `PASS` report; there is no silent fail-open.

The `— N/A:` escape is an **exact em-dash form** (em-dash, space, `N/A:`, non-empty reason).
A bare `N/A:`, a `- N/A:`, or a backticked `` `N/A:` `` inside explanatory text does **not**
count as the escape — those fall through to the report-path checks above.

The active workflow records its profile in `.workflow/state.md` (the **Profile** field —
see `shared/state.template.md`); `finish-branch` validates that profile's boxes before shipping.

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

## What a gate can honestly claim — Verified / Attested / Advisory

Be precise about the strength of each gate signal. A claim is only as strong as what
produced it:

- **Verified** — an out-of-turn check *recomputed* the fact, independent of the agent's
  say-so. Example: CI ran the test suite at the exact PR commit and it passed. This is the
  strongest signal, and the only one that survives a bad-faith or mistaken agent.
- **Attested** — an agent or human *claimed* it and something validated the claim's *shape*,
  not its truth. A `- [x]` box in `.workflow/state.md`, or `check-gates.sh` reporting the
  checklist is complete, is attested: it confirms the record says "done", not that the work
  was done. A file that says `reviewer_engine: codex` is not proof Codex reviewed anything.
- **Advisory** — present only as an instruction the agent is asked to follow. The workflow
  skills and this rules file are advisory.

**Never present an attested checkbox as if it were verified.** The honest upgrade path is to
move a claim up the ladder — e.g. bind "tests passing" to CI (verified) rather than a box
someone ticked (attested).

## How enforcement works here (advisory + Tier-B check + native prompt)

**Be honest about what this is: discipline, not a hard gate.** Nothing conditionally
blocks a commit when a box is unchecked. Three things stand in — none of them a hard block:

1. **Advisory (all engines):** you are instructed — here and in the workflow skill — not
   to ship until the profile's boxes pass. Honor it.
2. **Deterministic Tier-B check (all engines):** `finish-branch` runs
   `shared/scripts/check-gates.sh` (`.ps1` on Windows), which reads `.workflow/state.md` and
   exits non-zero listing any unchecked box. This turns "eyeball the file" into "run a
   command that fails loudly" — a much harder thing to rationalize past, and the *same*
   command a human or CI can run. It is still **attested** (it validates the record, not the
   work) and still **skippable** (Tier B runs only when invoked — it is not a hook). For a
   real *verified* gate, run it in CI with branch protection so the check binds to the PR
   commit outside the agent's turn.
3. **Best-effort native prompt (per engine):** each engine can prompt for human approval
   on outward commands — but it reads **no** gate state and matches commands by pattern,
   so it is bypassable (e.g. `git -C . push`, a PR via API, another tool):
   - **Claude Code** — `git push` / `gh pr create` are `ask`-tier in `.claude/settings.json`.
   - **Codex** — `approval_policy` in `.codex/config.toml` asks when a command crosses the
     sandbox boundary (not before every command).
   - **OpenCode** — `permission.bash` in `opencode.json` sets `git push*` / `gh pr create*`
     to `ask` (force-push `deny`).

The prompt shows the human a generic "allow this command?", **not** the checklist — so it
is a commit-confirmation, not proof the gates are green. The approver must
**independently check `.workflow/state.md` before approving** (or run `check-gates.sh`).

### Opt-in hard block (Tier C, Claude Code only)

For the one engine that supports it, `install.sh --with-hooks` (`-WithHooks` on PowerShell)
installs a Claude Code `PreToolUse` hook into `.claude/settings.local.json` that runs
`shared/scripts/claude-gate-hook.sh` — the same `check-gates.sh` behind a hook — and **exits 2
to actually block** `git commit` / `git push` / `gh pr create` when the gates are incomplete.
This is the only place forge-ai can hard-block. It is deliberately **not the default**: it's
per-developer (the local settings file is gitignored), Claude-Code-specific (breaks the
cross-engine promise, so it stays opt-in), and fails **open** if it can't verify. The gate is
still *attested* — it confirms the recorded boxes, not the underlying work. Codex/OpenCode have
the mechanism (see `docs/extending.md` Tier C) but no adapter ships yet.
