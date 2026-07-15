# Workflow discipline for Claude Code, Codex + OpenCode

> This file is the always-on instruction set. `AGENTS.md` is a symlink to it, so
> **Claude Code** (reads `CLAUDE.md`), **Codex** (reads `AGENTS.md`), and **OpenCode**
> (reads `AGENTS.md`, falls back to `CLAUDE.md`) all load the exact same discipline.
> One canonical source — no drift.

## What this is

A lightweight, **skills-and-config-only** workflow system. No hooks, no scripts —
enforcement is **advisory** (you follow the instructions) plus **native coarse gating**
on outward actions (push / PR). It runs identically under Claude Code, Codex, and OpenCode.

## Golden rules (always apply)

- **Never work on `main`.** Create a branch before changing code.
- **Pick the right workflow skill** for the task (see index below) and follow it.
- **`.workflow/state.md` is the source of truth** for the active workflow: its checklist
  gates shipping. Keep it updated as you progress. If it doesn't exist for the current
  task, start from `state.template.md`.
- **Do not ship until the gates pass.** Before `git commit` / `git push` /
  `gh pr create`, every required box in `.workflow/state.md` must be checked. See
  `shared/rules/ship-gates.md`.
- **Challenge, don't flatter.** Push back on weak ideas; verify claims against the code.
- **Ground your claims.** State what you verified vs. inferred; cite `file:line`.

## Workflow skills (canonical in `skills/`, discovered by all three harnesses)

- `new-feature` — full feature workflow (brainstorm → plan → cross-review → TDD → review → verify → ship)
- `fix-bug` — bug fix with systematic debugging (reproduce → root cause → failing test → fix → review → verify → ship)
- `quick-fix` — trivial changes (<3 files, no behavior risk); escalate if scope grows
- `review` — cross-engine second opinion on a plan or diff (P0–P3 findings)
- `finish-branch` — close out a branch: confirm gates → final verify → commit → push → PR

## Discipline reference (`shared/rules/`)

- `workflow.md` — when to use which skill; the phases
- `severity.md` — P0–P3 rubric for review findings
- `ship-gates.md` — what must be true before commit/push/PR, and how each harness gates it

## Enforcement model (read this — it's a deliberate trade)

This build has **no hard conditional block**. The skills instruct you to run the gates
before shipping (advisory). On top of that, each harness applies a **coarse native
approval** on outward actions:

- **Claude Code:** `git push` / `gh pr create` are `ask`-tier in `.claude/settings.json`
  (human approves).
- **Codex:** `approval_policy` in `.codex/config.toml` requires approval before running
  non-trivial shell commands.
- **OpenCode:** `permission.bash` in `opencode.json` sets `git push*` / `gh pr create*`
  to `ask` (and force-push to `deny`).

None of them read `.workflow/state.md` to decide — they always ask; you approve. A future
phase may add hook-based conditional blocking; see `docs/`.
