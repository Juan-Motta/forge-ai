# Design: `verify-e2e` skill

**Date:** 2026-07-19
**Branch:** `feat/verify-e2e-skill` (to be created)
**Status:** revised after cross-engine review (Codex `gpt-5.6-sol` + OpenCode `kimi-k3`) — ready for implementation plan

## Problem

forge-ai has no E2E verification. Across all three skills that ship a change
(`new-feature`, `fix-bug`, `finish-branch`), the "verify" step is a single instruction —
`new-feature/SKILL.md:47` says *"Actually exercise the change (run it, hit the endpoint,
drive the flow)"* — with no structure, no failure taxonomy, and no evidence binding. A
checked "verified" box is therefore a bare claim: nothing distinguishes a real end-to-end
run from an agent that typed `[x]`.

The 3-engine comparison against `claude-codex-forge` (2026-07-19) flagged this as the single
most valuable capability gap. This design adds E2E verification **as a pure skill + one
deterministic check** — no runtime hooks, no heavy dependencies, identical across Claude
Code, Codex, and OpenCode — closing the gap without betraying the thin-install / cross-engine
thesis.

## Non-goals (explicit YAGNI for v1)

- **Playwright `.spec.ts` regression bridge.** Deterministic zero-LLM CI replay pulls Node +
  a browser into the target. Deferred to v2 (documented in `src/docs/extending.md`).
- **Automatic multi-surface coverage audit.** v2.
- **"Investigate mode"** (read-only live DB/cloud fact-finding). Out of scope.
- **Cross-engine execution.** Unlike `review`/`council`, E2E is *deterministic execution*
  against interfaces, not judgment — model diversity adds no value and adds fragility. The
  driver runs it. `models.md` is unchanged.

## Decisions

Original brainstorming decisions, amended by the cross-engine review (changes marked ⇄):

- **Enforcement tier = Attested with evidence.** The skill writes a markdown report to
  `docs/e2e/reports/`; a deterministic check binds the gate box to that report. This is the
  `Attested` rung of `shared/rules/ship-gates.md` — stronger than Advisory, honestly short
  of Verified. The rule prose states this tier explicitly so the box name doesn't over-claim.
- **v1 surfaces = API + CLI executed; UI documented.** ⇄ UI is **not a v1 executed surface**:
  a UI-only outward change records `E2E verified — N/A: UI journey, no v1 adapter` (auditable),
  and the skill points at the v2 Playwright bridge. This removes the "documented yet
  conditionally executed" ambiguity — v1 executes API/CLI only.
- **Journeys are repo-first regression assets.** Passing use-cases graduate to
  `docs/e2e/use-cases/<feature>.md`; reports live in `docs/e2e/reports/`.
- ⇄ **`docs/e2e/` is committed, not gitignored.** Reports and use-cases are evidence and
  regression assets the next session/engine must read, and the git-based freshness check
  (below) requires them tracked. Secrets are kept out by the env-var rule in the schema.
- ⇄ **The gate box replaces, not adds.** The `standard` profile's bare
  "Change verified by actually exercising it" box becomes the E2E box — no redundancy, the
  `required=6` count invariant is preserved, and deleting the line drops the count to 5<6 so
  the existing count check catches evasion.

## Journey schema (portable markdown)

Neutral adaptation of the user-journey shape. Every use case MUST include:

| Field | Rule |
| --- | --- |
| **ID** | Stable slug, unique within the feature (e.g. `orders-create-and-list`). Used for graduation upserts and report cross-reference. |
| **Actor** | A specific role + situation. Bare "user"/"a user" is rejected. |
| **Scenario** | 1–2 sentences: starting state + trigger + desired outcome. No biography fluff. |
| **Interface** | `API` or `CLI` (v1 executed surfaces). |
| **Intent** | One sentence in the actor's terms — no endpoints, code, tables, or internal language. |
| **Setup** | Sanctioned interfaces only (public API, signup/login, app CLI, documented seed). MUST NOT perform the action under test. **Credentials/secrets come from env vars — never hard-coded, since graduated UCs are committed.** |
| **Steps** | ≥2 actor actions through the declared interface, in order (1 allowed only with an explicit note for a genuinely single-action outcome). |
| **Verification** | Surface-appropriate *observable* outcome + a meaningful "next observable thing" — not a bare status/exit code. |
| **Persistence** | Re-request / re-invoke through the same interface and confirm state stuck. `N/A` only for genuinely stateless reads (whitelist: pure read whose result depends only on test-controlled inputs, or an idempotent stateless computation). |

## Skill flow (`skills/verify-e2e/SKILL.md`)

1. **Locate use cases.** From the active plan (`new-feature`/`fix-bug`) or from
   `docs/e2e/use-cases/*.md` (regression mode).
2. **Validate shape.** Reject malformed UCs with a reason code before executing —
   `MISSING_ACTOR`, `MISSING_SCENARIO`, `SCENARIO_FLUFF`, `CHEAT_SETUP`, `THIN_VERIFICATION`,
   `MISSING_PERSISTENCE`, `TOO_SHALLOW`, `NOT_USER_JOURNEY`, `WRONG_INTERFACE`. A shape
   failure bounces back to rewrite the UC; it does not execute.
3. **ARRANGE (setup).** Sanctioned interfaces only. **Forbidden:** raw DB writes
   (`psql -c "INSERT"`, `mysql -e`, `mongosh --eval`), internal/undocumented endpoints,
   file-injection on disk. If the sanctioned path is broken → fix it (No Bugs Left Behind).
4. **ACT + VERIFY per interface adapter.** No cheating in VERIFY — assert only through the
   interface under test.
5. **Classify each UC and compute the top-level verdict** (truth table below).
6. **Write the evidence report** (below).
7. **Graduate** passing UCs to `docs/e2e/use-cases/<feature>.md` (ID-based upsert).

### Classification truth table

| Per-UC result | Meaning | Blocks ship? | Retry? |
| --- | --- | --- | --- |
| `PASS` | Works as specified | No | — |
| `FAIL_BUG` | Real product defect | **Yes** | No |
| `FAIL_STALE` | UC references a changed interface (endpoint/flag/selector renamed) | **Yes** until the UC is updated | No |
| `FAIL_INFRA` | Server down, timeout, transient | **Yes** if still failing after one retry | Once |
| `FAIL_INVALID_UC` | UC fails authoring discipline (a Step-2 reason code) | **Yes** (test-design failure) | No |

**Top-level `VERDICT: PASS` only if every required UC is `PASS`.** Any other per-UC result
(including `FAIL_INFRA` after its one retry) yields `VERDICT: FAIL`, and the report records
the per-UC reason. A `VERDICT: FAIL` report never satisfies the gate (see below).

## Interface adapters (v1)

- **API** — `curl` / `httpie`. Assert status, body, headers, and a follow-up request
  (e.g. `GET` the resource created by a `POST` via its `Location`).
- **CLI** — subprocess. Assert stdout/stderr + exit code, and a *second* invocation that
  observes the persisted state (e.g. `add` then `list`).

## Safety (ARRANGE/VERIFY execution)

The skill runs real commands against a running system. It MUST:

- **Default to a non-production target.** Require explicit confirmation before running any
  journey against a target that isn't clearly local/ephemeral; never assume prod is safe.
- **Take credentials only from env vars** (never hard-coded, never committed).
- **Redact secrets/tokens/PII** from captured output before writing the report (the report
  is committed).
- **Guard against command injection** when interpolating UC-provided values into shell
  commands (quote/escape; never `eval` raw UC text).
- **Clean up** resources it created where the interface allows, or note residual state in
  the report.

## Evidence report

Path: `docs/e2e/reports/<YYYY-MM-DD>-<feature>.md` (**committed**). Contents:

- A header line the freshness check can read: feature, branch, and an ISO-8601 timestamp.
- Top-level `VERDICT: PASS | FAIL`.
- Per-UC block: UC ID, classification, interface, observed output (trimmed, redacted), and
  the persistence re-check result.

> Same-day reruns overwrite the day's report (acceptable for v1; the header timestamp
> disambiguates the actual run time). A run-id suffix is a v2 nicety.

## Gate integration

- **`shared/rules/ship-gates.md`** — in the `standard` profile, **replace** the bare
  "Change verified by actually exercising it" box with:
  `- [ ] E2E verified via verify-e2e (report: docs/e2e/reports/<...>.md)`.
  Escape `- [x] E2E verified — N/A: <reason>` for purely internal changes (migration,
  refactor, dev tooling) and UI-only changes (no v1 adapter). The `required` count stays 6.
  Add prose noting this is an **Attested** signal (evidence exists), not the Verified tier.
- **`shared/state.template.md`** — mirror the same replacement in the `standard` checklist
  so the box reaches `.workflow/state.md`.
- **`shared/scripts/check-gates.sh` / `.ps1`** — add a check keyed on the named marker:

  When the state file's checklist contains `[x] E2E verified` (case-sensitive `x`,
  anchored to the ship-gate checklist section) **without** a `— N/A:` suffix, require a
  report in `docs/e2e/reports/` that is BOTH:
  1. **Verdict-valid** — its top-level line is `VERDICT: PASS`; and
  2. **Fresh, determined by git (not mtime)** — the report path appears in
     `git diff --name-only <base>..HEAD -- docs/e2e/reports/` **or** is an untracked file
     under that dir, where `<base>` = `git merge-base HEAD <default-branch>` and the default
     branch is detected as `main` then `master`.

  Otherwise exit non-zero with a specific message ("E2E box checked but no fresh PASS report
  produced"). **Degrade gracefully (skip this check, not fail)** when: on the default branch,
  no merge-base resolvable, or no git history — matching how the E2E N/A escape and the rest
  of the validator behave. `check-gates.sh` has **no** git logic today, so this is new code,
  specified here rather than "mirrored".
  - The `— N/A:` escape must carry a non-empty reason or the box is treated as unchecked.

## Skill wiring

- **`skills/new-feature/SKILL.md` step 6 (Verify)** — replace the free-text "exercise the
  change" with "run the `verify-e2e` skill; for purely internal or UI-only changes, record
  `E2E verified — N/A: <reason>`."
- **`skills/fix-bug/SKILL.md`** — invoke `verify-e2e` **in addition to** the existing
  original-repro and neighbor checks at `fix-bug/SKILL.md:44-48` (do not remove them).
- **`skills/finish-branch/SKILL.md`** — its gate confirmation already runs `check-gates.sh`,
  which now enforces the E2E marker. It relies on the report produced during the workflow;
  it does not re-run journeys. Note this so evidence isn't regenerated redundantly.
- **`shared/rules/docs-layout.md`** — register `docs/e2e/` (`reports/` + `use-cases/`),
  following the existing installer-scaffolded `.gitkeep` pattern (`docs-layout.md:18`).
- **`src/CLAUDE.md`** — add `verify-e2e` to the canonical skill index (required: the linter
  hard-errors on index parity, `tools/lib/skill-lint.mjs:118-119`).
- **`src/docs/extending.md`** — document the v2 Playwright bridge, UI adapter, and
  multi-surface audit as the extension path.

## Files touched

**New**
- `src/skills/verify-e2e/SKILL.md` — the skill.
- `src/docs/e2e/{reports,use-cases}/.gitkeep` — scaffold seed (committed empty).

**Edited**
- `src/skills/new-feature/SKILL.md`, `src/skills/fix-bug/SKILL.md` (verify step).
- `src/shared/rules/ship-gates.md` (replace box in `standard`; Attested-tier prose).
- `src/shared/state.template.md` (mirror the box replacement).
- `src/shared/scripts/check-gates.sh` + `check-gates.ps1` (named-marker + verdict + git-freshness).
- `src/shared/rules/docs-layout.md` (register `docs/e2e/`).
- `src/CLAUDE.md` (skill index parity — otherwise the linter fails).
- `install.sh` (docs-dir enumeration ~`:181`) + `install.ps1` (~`:172`) — add `e2e` (with its
  `reports`/`use-cases` subdirs) to the scaffolded docs dirs, or `docs/e2e/` never reaches
  target installs. Update the installer smoke assertions accordingly.
- `src/docs/extending.md` (v2 notes).
- `tools/evals/routing-cases.json` (routing cases — see Testing).

## Testing

- **Routing eval:** add positive prompts for `verify-e2e` **and negative cases** (every
  existing entry pairs negatives). The new skill's `description` must be lexically distanced
  from `finish-branch` / `new-feature` "verify…end to end" vocabulary — `run-evals.mjs` fails
  on cosine collision ≥0.75. Add negatives asserting `finish-branch`/`new-feature`/`fix-bug`
  prompts do **not** route to `verify-e2e`, and vice-versa.
- **Skill lint:** `tools/lint-skills.mjs` must pass — including index parity (hence the
  `src/CLAUDE.md` edit), an anti-rationalization table, a red-flags section, a verification
  checklist, and no hard-coded model ids.
- **Unit test** (`tools/test/check-gates.test.mjs`, plus a mirrored PowerShell fixture for
  `.ps1` parity — Windows CI currently exercises only the count path, `ci.yml:65-78`):
  (a) box checked + fresh PASS report → pass; (b) box checked + no report → fail;
  (c) box checked + report present but `VERDICT: FAIL` → fail; (d) box checked + report not
  changed on this branch (stale, mtime-fresh) → fail; (e) `— N/A: <reason>` → skip;
  (f) `— N/A:` empty reason → treated as unchecked; (g) degraded env (no merge-base) → skip;
  (h) old 6-box state file without the E2E box name → count check still catches a missing box.
- **Backward-compat acceptance:** a re-install over an in-flight branch must keep old 6-box
  state files green (the replace-not-add design guarantees this — assert it).
- **Manual cross-engine smoke:** author one API UC + one CLI UC against a throwaway target,
  run the skill under Claude Code, Codex, and OpenCode; confirm identical behavior and a
  written report on each.

## Acceptance criteria

- [ ] `verify-e2e` skill exists, is in the `src/CLAUDE.md` index, and passes the linter.
- [ ] Malformed UCs are rejected with a reason code before execution.
- [ ] API and CLI journeys execute and produce a classified per-UC report with a top-level
      verdict in `docs/e2e/reports/`.
- [ ] Top-level `VERDICT: PASS` iff every required UC passes; `FAIL_INFRA` after one retry
      counts as failure.
- [ ] Passing UCs graduate to `docs/e2e/use-cases/<feature>.md` via ID-based upsert.
- [ ] `standard` profile's verify box is **replaced** by the E2E box (count stays 6);
      `state.template.md` mirrors it.
- [ ] `check-gates.sh`/`.ps1` bind the box to a **fresh PASS** report by named marker, using
      git (not mtime) for freshness, with the `N/A:` escape and graceful degradation; sh↔ps1
      parity covered by fixtures.
- [ ] `docs/e2e/` is scaffolded by both installers and reaches target installs.
- [ ] `new-feature` / `fix-bug` reference the skill; `fix-bug` keeps its repro/neighbor checks.
- [ ] Routing eval (positives + negatives, no ≥0.75 collision) and unit tests pass in CI.
- [ ] Secrets never hard-coded in UCs; report output is redacted.
