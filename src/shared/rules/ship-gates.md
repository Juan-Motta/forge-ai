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
directory". For the checked box, the line itself must name **exactly one** report (more
than one `(report: …)` group on the line is rejected as ambiguous — see below), and that
named path must:

1. **match a strict whitelist** — `^docs/e2e/reports/[A-Za-z0-9._-]+\.md$` (a bare filename
   directly under `docs/e2e/reports/`, no `..`, no subdirectories, no absolute path). This
   also rejects the `<...>` placeholder, since `<`/`>` fall outside the allowed charset;
2. **be a regular file, not a symlink** — resolved against the git toplevel, not the
   current directory; a symlink at the named path (e.g. pointing outside the repo at a
   fabricated report) is rejected before existence is even checked;
3. **exist** as that regular file;
4. **carry a top-level `VERDICT: PASS`** — the *first* `VERDICT:` line must be exactly
   `VERDICT: PASS` (a per-UC `PASS` under a top-level `FAIL`, or `VERDICT: PASS extra`, fails);
5. **be fresh on this branch** — the path must be new work (committed since the branch
   point, staged, an unstaged tracked edit, or untracked).

The branch **base is auto-detected** by the *closest* merge-base among
`dev`, `main`, `master`, and their `origin/…` counterparts (plus `origin/HEAD`), so it
works whether the repo integrates on `dev` or `main`. Freshness is **best-effort**: if no
base ref resolves (single-branch or detached HEAD), freshness is skipped **with a note to
stderr** — but the whitelist, symlink-rejection, existence, and top-level `PASS` checks are
*always* enforced regardless of freshness.

**Scope of the guarantee — be precise, not sweeping.** This closes a specific, named set of
bypasses on the *record*: a checked box can't point at a placeholder, a path outside
`docs/e2e/reports/` (traversal or absolute), a subdirectory, a **leaf symlink** at the named
path, or an ambiguous multi-report line — and it can't point at a stale/inherited report once
a base resolves. That is the full extent of what `check-gates` proves. It does **not** prove
the report's *content* is true: the file at that path still says whatever an agent or human
wrote into it. It also does not defend against filesystem indirection such as a symlinked
ancestor directory. A committed report with a hand-typed `VERDICT: PASS` and no verify-e2e run
behind it satisfies every check above. This is the **Attested** tier (see the Verified /
Attested / Advisory ladder below) — the record's *shape* is validated, not the underlying
claim. Only the **Verified** tier — an out-of-turn CI job that re-runs `verify-e2e` itself
against the PR commit, independent of the agent's say-so — is bypass-proof against a
bad-faith or mistaken attestation.

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
  say-so. The concrete mechanism codeforge ships for this: `docs/ci-templates/gates.yml`,
  copied into `.github/workflows/`, its test step filled in, and made a **required status
  check** under branch protection (bypass disabled) — it reruns your tests on the PR's merge
  commit, outside any agent's turn. This is the strongest signal in the ladder, but it binds
  against a bad-faith or mistaken agent **only when all three hold**: (1) the workflow file
  itself is **CODEOWNERS-protected** with required code-owner review — otherwise a PR can edit
  `.github/workflows/gates.yml` in the same PR it's supposed to gate, and GitHub runs that PR's
  own (weakened) version; (2) **"Require branches to be up to date before merging"** (strict
  checks) is enabled, or a merge queue is used — otherwise the base can advance after the check
  ran and the tested merge commit is not the code that actually lands; and (3) "do not allow
  bypassing" covers admins. Absent any one of these, the tier degrades toward Attested. See
  `docs/ci-templates/README.md` for setup. Repo/org admins can still bypass branch protection
  unless you've configured otherwise.
- **Attested** — an agent or human *claimed* it and something validated the claim's *shape*,
  not its truth. A `- [x]` box in `.workflow/state.md`, or `check-gates.sh` reporting the
  checklist is complete, is attested: it confirms the record says "done", not that the work
  was done. A file that says `reviewer_engine: codex` is not proof Codex reviewed anything.
- **Advisory** — present only as an instruction the agent is asked to follow. The workflow
  skills and this rules file are advisory.

**Never present an attested checkbox as if it were verified.** The honest upgrade path is to
move a claim up the ladder — e.g. bind "tests passing" to CI (verified) rather than a box
someone ticked (attested).

## How enforcement works here (advisory + Tier-B check + native prompt, locally — CI is the real gate)

**Be honest about what this is: locally, discipline, not a hard gate.** Nothing conditionally
blocks a commit when a box is unchecked on your machine. Three things stand in locally — none
of them a hard block — plus one thing that actually binds, in CI:

1. **Advisory (all engines):** you are instructed — here and in the workflow skill — not
   to ship until the profile's boxes pass. Honor it.
2. **Deterministic Tier-B check (all engines):** `finish-branch` runs
   `shared/scripts/check-gates.sh` (`.ps1` on Windows), which reads `.workflow/state.md` and
   exits non-zero listing any unchecked box **or any missing required gate**. It validates the
   profile's gates by **identity, not just count** — a checklist with the right number of
   checked boxes but renamed or omitted gates is rejected, so the box wording must name each
   required gate (the canonical wording lives in `shared/state.template.md`). This turns
   "eyeball the file" into "run a command that fails loudly" — a much harder thing to
   rationalize past, and the *same* command a human or CI can run. It is still **attested** (it
   validates the record, not the work) and still **skippable** (Tier B runs only when invoked —
   it is not a hook).
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

4. **The hard gate (binds for everyone): CI + branch protection.** codeforge ships
   `docs/ci-templates/gates.yml` as the concrete **Verified**-tier mechanism. Copy it into
   `.github/workflows/gates.yml`, fill in its test step, and make it a **required status
   check** with branch protection ("do not allow bypassing" enabled) — it then reruns your
   tests on the PR's merge commit, outside any agent's turn, and no local skip or engine
   choice can get around it, **provided** the workflow file is CODEOWNERS-protected and
   strict/up-to-date checks (or a merge queue) are on — see the preconditions under
   "Verified" above and `docs/ci-templates/README.md`. With those in place, this is the
   **only** signal in this ladder that binds for every clone and every merge. Repo/org
   admins can still bypass branch protection unless you've configured otherwise — decide
   who that should be. There are no per-engine runtime hooks in codeforge; local
   enforcement is advisory + the Tier-B check above.
