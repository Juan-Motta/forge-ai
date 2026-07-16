# Project index

> High-level map for fast orientation. See `README.md` for the full explanation. Refresh
> with the `index` skill after significant structural changes.
>
> Updated: 2026-07-16

## What it is

Interoperable workflow discipline for the Claude Code, Codex, and OpenCode CLIs — skills +
config only, no runtime scripts. Full overview in `README.md`.

## Entry points

- **Working on forge-ai (this repo):** root `CLAUDE.md` (thin dev orientation) → `PROJECT.md`
  (project rules) → `CONTINUITY.md` (handoff → Next step).
- **The shippable payload:** everything under `template/` (see below).
- **Install into another project:** `./install.sh <target-dir> [--upgrade]`.

## Where things live

### Payload — `template/` (what `install.sh` copies into a target)

| Path | Purpose |
| --- | --- |
| `template/CLAUDE.md` | Canonical always-on instructions (target's `AGENTS.md` symlinks to it) |
| `template/skills/<name>/SKILL.md` | The workflows: `prd`, `research`, `plan`, `new-feature`, `fix-bug`, `quick-fix`, `review`, `council`, `finish-branch`, `checkpoint`, `index` |
| `template/shared/rules/*.md` | Discipline: workflow, severity, ship-gates, tdd, research, approach-comparison, memory, docs-layout, continuity, models, project-rules |
| `template/.claude/settings.json` · `template/.codex/config.toml` · `template/opencode.json` | Per-engine config + native push/PR gates (copied to target) |
| `template/docs/extending.md` + empty `prds/ plans/ research/ solutions/ adr/` | Docs scaffold for the target |
| `template/*.template.md` | Blanks: `state`, `CONTINUITY`, `PROJECT` |

### Repo files — NOT payload (never travel to a target)

| Path | Purpose |
| --- | --- |
| `install.sh` | Copy-based installer (copies `template/*` → target root, creates symlinks) |
| `README.md` · `LICENSE` | Framework docs + license |
| `.claude/` (root) | Minimal dev config for working ON forge-ai (push/PR gate only) |
| `CLAUDE.md` (root) | Thin dev orientation for this repo (payload's instructions are in `template/`) |
| `PROJECT.md` · `CONTINUITY.md` | This repo's own project rules + session handoff |
| `docs/` (root) | This repo's own history: `CHANGELOG.md`, `adr/`, design notes, `index.md` |

## Conventions

- **Payload vs repo:** the installable discipline lives in `template/`; the framework's own
  dev/meta files live at the root and never ship. Edit `template/**` to change what forge-ai
  ships.
- **Symlinks only in the target:** `template/` holds no symlinks — `install.sh` creates
  `AGENTS.md → CLAUDE.md` and `.<engine>/skills → ../skills` in the target after copying.
- **`SKILL.md`:** the directory name must equal the frontmatter `name`; filename uppercase.
- **Tiers** (`template/docs/extending.md`): A = skills-only · B = skills + scripts · C = hooks.
  Prefer the lowest tier that works.
- **Enforcement:** advisory + native push/PR approval (no hard conditional blocking).
- **Never use git worktrees** — simple branch only.
