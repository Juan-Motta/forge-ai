---
name: fix-bug
description: Bug-fix workflow with systematic debugging — reproduce with a failing test, isolate root cause, fix minimally, cross-review, verify, and ship behind the ship-gate. Use when correcting incorrect behavior under Claude Code, Codex, or OpenCode.
---

# fix-bug

Fix a defect with evidence, not guesses. Works identically under all three engines.

## 0. Set up tracking

- Confirm you are **not on `main`** — create a branch (`fix/<name>`).
- Copy `state.template.md` to `.workflow/state.md`; set skill = `fix-bug`, feature/bug
  name, branch, and driver.

## 1. Reproduce

Reproduce the bug deterministically. Capture the exact input, expected vs actual, and the
smallest failing case. Do not propose a fix until you can trigger it on demand.

## 2. Root cause (systematic debugging)

Form a hypothesis, add logging/assertions to test it, and confirm the actual cause before
touching the fix. Read the relevant code and cite `file:line`. Distinguish what you
verified from what you infer.

## 3. Failing test first (TDD)

Write a test that fails **because of the bug** (red) — see `shared/rules/tdd.md`. This
proves the repro and prevents regression. For a high-impact surface, also design-review
the fix approach with the `review` skill (a different engine) before implementing.

## 4. Fix minimally

Make the smallest change that turns the test green. Refactor only if it clarifies. Fix
the real cause, not the symptom.

## 5. Code review (cross-engine)

Review the diff with the **other** engine (`review` skill; models per
`shared/rules/models.md`) + a self-pass; resolve all P0/P1/P2 (`shared/rules/severity.md`).
Record iterations in `.workflow/state.md`.

## 6. Verify

Exercise the original repro and confirm it's gone; check you didn't break neighbors.
Note what you observed. Record the fix (symptom → root cause → fix → how verified) in
`docs/solutions/<slug>.md` (`shared/rules/memory.md`).

## 7. Ship

Only when every required box in `.workflow/state.md` is checked
(`shared/rules/ship-gates.md`). Commit, then push / open PR — approve the native prompt
only if the gates are green.
