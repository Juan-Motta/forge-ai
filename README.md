# forge-ai

Interoperable workflow discipline for **Claude Code** and **Codex** — the simplest
possible form: skills + config only. No hooks, no scripts.

## How it works

- **One canonical instruction set:** `CLAUDE.md` (Claude reads it) with `AGENTS.md` as a
  symlink (Codex reads it). Same discipline, no drift.
- **One canonical skills folder:** `skills/<name>/SKILL.md`, using the `SKILL.md`
  convention both harnesses share. Symlinked into each harness's discovery path:
  - `.claude/skills -> ../skills` (Claude Code)
  - `.codex/skills -> ../skills` (Codex)
- **Shared discipline reference:** `shared/rules/*.md` (workflow, severity, ship-gates).
- **Native coarse gating** (no scripts):
  - Claude Code: `.claude/settings.json` — `git push` / `gh pr create` are `ask`-tier.
  - Codex: `.codex/config.toml` — `approval_policy` pauses for approval.

## Enforcement is advisory + native approval

There is no hook that conditionally blocks a commit when gates are unmet. The skills
instruct you to pass the gates before shipping, and the native approval prompt on
push/PR is the human backstop. See `shared/rules/ship-gates.md`.

## Usage

- **Claude Code:** open this project; `CLAUDE.md` and `.claude/skills/` load automatically.
- **Codex:** open this project; `AGENTS.md` and `.codex/skills/` load automatically.
  Trust the project when prompted.

Start a feature with the `new-feature` skill.

## Status

First skeleton (2026-07-15). Skills: `new-feature`. More (fix-bug, quick-fix, review,
finish-branch) to follow.
