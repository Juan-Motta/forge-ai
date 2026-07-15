# forge-ai

Interoperable workflow discipline for **Claude Code**, **Codex**, and **OpenCode** — the
simplest possible form: skills + config only. No hooks, no scripts.

## How it works

- **One canonical instruction set:** `CLAUDE.md` with `AGENTS.md` as a symlink to it.
  Claude Code reads `CLAUDE.md`; Codex and OpenCode read `AGENTS.md` (OpenCode falls back
  to `CLAUDE.md`). Same discipline, no drift.
- **One canonical skills folder:** `skills/<name>/SKILL.md`, using the `SKILL.md`
  convention all three share. Symlinked into each harness's discovery path:
  - `.claude/skills -> ../skills` (Claude Code — also read directly by OpenCode)
  - `.codex/skills -> ../skills` (Codex)
  - `.opencode/skills -> ../skills` (OpenCode)
- **Shared discipline reference:** `shared/rules/*.md` (workflow, severity, ship-gates).
- **Native coarse gating** (no scripts):
  - Claude Code: `.claude/settings.json` — `git push` / `gh pr create` are `ask`-tier.
  - Codex: `.codex/config.toml` — `approval_policy` pauses for approval.
  - OpenCode: `opencode.json` — `permission.bash` sets push/PR to `ask`, force-push to `deny`.

## Enforcement is advisory + native approval

There is no hook that conditionally blocks a commit when gates are unmet. The skills
instruct you to pass the gates before shipping, and the native approval prompt on
push/PR is the human backstop. See `shared/rules/ship-gates.md`.

## Usage

- **Claude Code:** open this project; `CLAUDE.md` and `.claude/skills/` load automatically.
- **Codex:** open this project; `AGENTS.md` and `.codex/skills/` load automatically.
  Trust the project when prompted.
- **OpenCode:** open this project; `AGENTS.md` and the skills load automatically;
  `opencode.json` applies the push/PR approval gate.

Start a feature with the `new-feature` skill.

## Status

Skeleton (2026-07-15). Engines: Claude Code, Codex, OpenCode. Skills: `new-feature`,
`fix-bug`, `quick-fix`, `review`, `finish-branch`.
