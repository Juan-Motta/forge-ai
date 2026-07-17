---
name: new-feature
description: Full feature workflow — research, plan, cross-engine design review, TDD, code review, verify, and ship behind the ship-gate. Use when starting any new feature or behavior change under Claude Code, Codex, or OpenCode.
---

# new-feature

Drive a feature from idea to shipped change with cross-engine review discipline. Works
identically under Claude Code, Codex, and OpenCode.

## 0. Set up tracking

- Confirm you are **not on `main`** — create a branch (`feat/<name>`).
- Copy `shared/state.template.md` to `.workflow/state.md`; set **Profile: standard**, the feature name, and branch.

## 1. Research (when external tech is involved)

If the feature touches an unfamiliar or external library/API/protocol, run the `research`
skill first and write a sourced brief (`shared/rules/research.md`). Skip only for changes
fully contained in code you already understand.

## 2. Plan

Clarify intent, then compare 2–3 approaches and pick one — use the `plan` skill and the
fixed axes in `shared/rules/approach-comparison.md`. Capture the goal, chosen approach,
files/units to touch, edge cases, the test plan, and acceptance criteria. Keep units
small. Do not write implementation code yet.

## 3. Design review (cross-engine)

Validate the plan with the `review` skill (a *different* engine reviews) — or `council`
for a hard fork. Reviewer/advisor models come from `shared/rules/models.md`. Collect
findings by severity (`shared/rules/severity.md`); resolve P0/P1/P2; record the iteration
in `.workflow/state.md`.

## 4. TDD

Red → green → refactor (`shared/rules/tdd.md`). Write the failing test first, make it pass
minimally, then refactor. Never write implementation before a failing test exists.

## 5. Code review (cross-engine)

Review the diff with the `review` skill (the other engine) + a self-pass. Fix all
P0/P1/P2. Repeat until a single pass is clean. Record iterations in `.workflow/state.md`.

## 6. Verify

Actually exercise the change (run it, hit the endpoint, drive the flow) — do not rely on
tests alone. Note what you observed.

## 7. Ship

Only when every required box in `.workflow/state.md` is checked (`shared/rules/ship-gates.md`).
Commit, then push / open PR — approve the native prompt **only if the gates are green**.
Record the change in `docs/CHANGELOG.md` and save any reusable learning
(`shared/rules/memory.md`). Or run `finish-branch` to do the wrap-up.
