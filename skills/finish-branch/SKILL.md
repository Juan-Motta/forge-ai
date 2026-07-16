---
name: finish-branch
description: Wrap up a completed branch — confirm the ship-gate profile is green, do a final verify, record durable docs, then commit, push, and open the PR. Use to close out work under Claude Code, Codex, or OpenCode after the feature/fix workflow is done.
---

# finish-branch

Close out a branch cleanly. This does not replace the feature/fix workflow — it's the
final step after one.

## 1. Confirm the gates

Open `.workflow/state.md` and verify **every required box for the active gate profile** is
checked (`shared/rules/ship-gates.md`): branch, plan reviewed, tests passing, code review
clean, verified, state updated. If any box is open, go back and finish it — do not ship.

## 2. Final verify

Run the test suite and exercise the change once more end-to-end. Confirm the working tree
is otherwise clean and the branch is up to date.

## 3. Record durable docs — BEFORE shipping

Do this **before** the ship commit so the documentation ships *with* the change (not left
uncommitted, and never as a second unreviewed commit):

- Add a newest-first entry to `docs/CHANGELOG.md` (`shared/rules/docs-layout.md`).
- Save any reusable learning per `shared/rules/memory.md` (solved bugs → `docs/solutions/`,
  decisions → `docs/adr/`).

## 4. Commit

Commit all intended changes **including the docs from step 3** with a clear message.
Nothing uncommitted, no stray files.

## 5. Push + open PR

Push the branch and open the PR. Both hit the **native prompt** (a commit-confirmation, not
a gate — `shared/rules/ship-gates.md`) — approve only because you just confirmed the gates
in step 1. Write a PR description stating what changed, why, and how it was verified.

## 6. Update transient state

Only now — after shipping — record the PR link / merge outcome in `.workflow/state.md` so
the workflow state reflects reality. (This is the one thing that legitimately comes after
the ship commit.)
