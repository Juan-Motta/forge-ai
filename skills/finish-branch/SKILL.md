---
name: finish-branch
description: Wrap up a completed branch — confirm the ship-gate is green, do a final verify, then commit, push, and open the PR. Use to close out work under Claude Code, Codex, or OpenCode after the feature/fix workflow is done.
---

# finish-branch

Close out a branch cleanly. This does not replace the feature/fix workflow — it's the
final step after one.

## 1. Confirm the gates

Open `.workflow/state.md` and verify **every required box is checked**
(`shared/rules/ship-gates.md`): on a branch, plan reviewed, tests passing, code review
clean (no open P0/P1/P2), change verified, state updated. If any box is open, go back and
finish it — do not ship.

## 2. Final verify

Run the test suite and exercise the change once more end-to-end. Confirm the working tree
is clean and the branch is up to date.

## 3. Commit

Ensure all intended changes are committed with a clear message. Nothing uncommitted, no
stray files.

## 4. Push + open PR

Push the branch and open the PR. Both actions hit the **native approval prompt** — approve
only because you have just confirmed the gates are green in step 1. Write a PR description
that states what changed, why, and how it was verified.

## 5. Record

Note in `.workflow/state.md` that the branch was finished (PR link / merge outcome), so
the workflow state reflects reality.
