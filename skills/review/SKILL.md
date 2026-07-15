---
name: review
description: Get a cross-engine second opinion on a plan or a code diff — run the other engine as reviewer, collect severity-tagged findings (P0–P3), and report. Use during the design-review and code-review phases under Claude Code, Codex, or OpenCode.
---

# review

A utility skill for the review phases of other workflows. The point is **model
diversity**: the reviewer must be a *different* engine than the one driving.

## 1. Identify the target

- **Plan review** — a written plan/spec before implementation.
- **Code review** — the current diff (uncommitted, or vs `main`).

State which, and the exact scope (file paths, base ref).

## 2. Pick the reviewer (must differ from the driver)

- Driver Claude Code → reviewer Codex (`codex exec ...`) or OpenCode (`opencode run ...`).
- Driver Codex → reviewer Claude (`claude -p ...`) or OpenCode.
- Driver OpenCode → reviewer Claude or Codex.

Give the reviewer the target + this instruction: report findings tagged by severity
(`shared/rules/severity.md`) with location and a concrete fix.

## 3. Collect findings

Gather the reviewer's output as P0/P1/P2/P3 items. If output is missing or unparseable,
treat it as a failed review — re-run, do not fabricate a verdict.

## 4. Act and record

- Resolve all P0/P1/P2 (P3 optional). Re-run the reviewer until a pass is clean.
- Record each iteration and its result in `.workflow/state.md` (which engine, findings).

## Verification

The loop exits only when a single pass from the reviewer yields no P0/P1/P2. State that
explicitly before returning to the calling workflow.
