---
name: verify-e2e
description: Execute user-journey use cases (API and CLI in v1) against the running app, classify each, and write a committed evidence report the ship-gate binds to. Use to verify a user-facing change end to end before shipping, under Claude Code, Codex, or OpenCode.
---

# verify-e2e

Run **user journeys** — not unit tests — against real interfaces, then bind the result to
the ship-gate with an evidence report. API and CLI are executed in v1; UI is deferred
(record `E2E verified — N/A: UI journey, no v1 adapter`). The driver runs this; it is not a
cross-engine review.

## 0. Locate use cases

From the active plan (`new-feature` / `fix-bug`) or, in regression mode, from
`docs/e2e/use-cases/*.md`.

## 1. Validate journey shape (before executing)

Each use case MUST carry: **ID, Actor, Scenario, Interface (API|CLI), Intent, Setup, Steps
(≥2), Verification, Persistence**. Reject a malformed UC with a reason code and stop —
rewrite it, don't execute it:

- `MISSING_ACTOR` · `MISSING_SCENARIO` · `SCENARIO_FLUFF` · `CHEAT_SETUP` (Setup performs the
  action under test) · `THIN_VERIFICATION` (bare status/exit code) · `MISSING_PERSISTENCE` ·
  `TOO_SHALLOW` (<2 meaningful steps) · `NOT_USER_JOURNEY` (reads as a unit/contract test) ·
  `WRONG_INTERFACE`.

## 2. ARRANGE — sanctioned setup only

Public API, signup/login, app CLI, or documented seed commands. **Forbidden:** raw DB writes
(`psql -c "INSERT"`, `mysql -e`, `mongosh --eval`), internal/undocumented endpoints,
file-injection on disk. A broken sanctioned path is a **finding, not a fix-it-here**: report
it (verify runs read-only) and loop the repair back through `fix-bug` / `new-feature` so the
app change gets its own tests and review — **never route around it** and never patch app code
inline during the verify phase. Credentials come from **env vars**, never hard-coded
(graduated use cases are committed).

## 3. Safety

- Default to a **non-production** target; require explicit confirmation otherwise.
- **Redact** secrets/tokens/PII from captured output before writing the report.
- Quote/escape UC-provided values; never `eval` raw UC text.
- Clean up resources you created, or note residual state in the report.

## 4. ACT + VERIFY per interface

- **API** — `curl`/`httpie`: assert status, body, headers, AND a follow-up request (e.g. GET
  the resource a POST created via its `Location`).
- **CLI** — subprocess: assert stdout/stderr + exit code, AND a second invocation that
  observes the persisted state (e.g. `add` then `list`).

No cheating in VERIFY: assert only through the interface under test.

## 5. Classify + verdict

| Result | Blocks ship? | Retry |
| --- | --- | --- |
| `PASS` | no | — |
| `FAIL_BUG` | yes | no |
| `FAIL_STALE` (UC references a renamed interface) | yes, until UC updated | no |
| `FAIL_INFRA` (server down/timeout) | yes if still failing after 1 retry | once |
| `FAIL_INVALID_UC` | yes | no |

**Top-level `VERDICT: PASS` only if every required UC is `PASS`.** Anything else →
`VERDICT: FAIL`.

## 6. Write the evidence report

`docs/e2e/reports/<YYYY-MM-DD>-<feature>.md` (committed). Include a header line
(feature, branch, ISO-8601 timestamp), the top-level `VERDICT: PASS|FAIL`, and one block per
UC (ID, classification, interface, trimmed+redacted output, persistence re-check).

## 7. Graduate passing use cases

Upsert each `PASS` UC by its **ID** into `docs/e2e/use-cases/<feature>.md` so later sessions
re-run it. Then check the `E2E verified` ship-gate box (or record `— N/A: <reason>`).

## Common rationalizations

| Rationalization | Reality |
| --- | --- |
| "Tests pass, that's enough." | Unit tests miss wiring/integration/UX. A journey exercises the real interface. |
| "I'll assert the status code and move on." | A bare 200/exit-0 is `THIN_VERIFICATION`. Observe a real outcome + a next observable step. |
| "I'll seed the row straight into the DB." | Raw DB writes are forbidden ARRANGE. Use the sanctioned interface; if it's broken, report it as a finding and loop through `fix-bug`. |
| "Just check the box — the report can wait." | `check-gates` binds the box to a fresh `VERDICT: PASS` report; an empty claim fails the gate. |
| "It's a read endpoint, skip Persistence." | Only genuinely stateless reads may use `Persistence: N/A`. |

## Red flags

- A use case with no Actor/Scenario, or an Intent naming endpoints/tables/components.
- Setup that performs the very action the UC is meant to test.
- Checking the `E2E verified` box without a committed `VERDICT: PASS` report on this branch.
- Verifying through a back channel (DB/logs) instead of the interface under test.

## Verification

- [ ] Every use case validated for shape before execution.
- [ ] API/CLI journeys executed; VERIFY only through the interface under test.
- [ ] Report written to `docs/e2e/reports/` with a top-level verdict; secrets redacted.
- [ ] Passing UCs graduated to `docs/e2e/use-cases/<feature>.md` by ID.
- [ ] `E2E verified` gate box checked only with a fresh `VERDICT: PASS` report (or `N/A:`).
