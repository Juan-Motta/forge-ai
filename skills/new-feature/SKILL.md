---
name: new-feature
description: Full feature workflow — brainstorm, plan, dual-engine design review, TDD, code review, verify, and ship behind the ship-gate. Use when starting any new feature or behavior change under Claude Code or Codex.
---

# new-feature

Drive a feature from idea to shipped change with cross-engine review discipline. Works
identically under Claude Code and Codex.

## 0. Set up tracking

- Confirm you are **not on `main`** — create a branch (`feat/<name>`).
- Copy `state.template.md` to `.workflow/state.md` and fill in the feature name + branch.

## 1. Brainstorm

Clarify intent, constraints, and success criteria **before** designing. Ask one question
at a time when something is genuinely ambiguous; otherwise state assumptions and proceed.
Do not write code yet.

## 2. Plan

Write the approach: files to touch, edge cases, and the tests that will prove it. Keep
units small and single-purpose.

## 3. Design review (cross-engine)

Get a second opinion from the **other** engine before implementing:

- If Claude is driving → have Codex review the plan (`codex exec ...`).
- If Codex is driving → have Claude review the plan (`claude -p ...`).

Collect findings by severity (`shared/rules/severity.md`); resolve P0/P1/P2; record the
iteration in `.workflow/state.md`.

## 4. TDD

Red → green → refactor. Write the failing test first, make it pass minimally, then
refactor. Never write implementation before a failing test exists.

## 5. Code review (cross-engine)

Review the diff with the other engine + a self-pass. Fix all P0/P1/P2. Repeat until a
single pass is clean. Record iterations in `.workflow/state.md`.

## 6. Verify

Actually exercise the change (run it, hit the endpoint, drive the flow) — do not rely on
tests alone. Note what you observed.

## 7. Ship

Only when every required box in `.workflow/state.md` is checked (`shared/rules/ship-gates.md`).
Commit, then push / open PR — approve the native prompt **only if the gates are green**.
