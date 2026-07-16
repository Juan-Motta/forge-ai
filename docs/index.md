# Project index

> High-level map for fast orientation. See `README.md` for the full explanation. Refresh
> with the `index` skill after significant structural changes.
>
> Updated: 2026-07-15

## What it is

Interoperable workflow discipline for the Claude Code, Codex, and OpenCode CLIs — skills +
config only, no runtime scripts. Full overview in `README.md`.

## Entry points

- **Instructions (auto-loaded):** `CLAUDE.md` (canonical) · `AGENTS.md` (symlink → `CLAUDE.md`).
- **Session start:** read `CONTINUITY.md` (handoff → Next step), then `PROJECT.md` (project rules).
- **Install into another project:** `./install.sh <target-dir> [--upgrade]`.

## Where things live

| Path | Purpose |
| --- | --- |
| `skills/<name>/SKILL.md` | The workflows: `prd`, `research`, `plan`, `new-feature`, `fix-bug`, `quick-fix`, `review`, `council`, `finish-branch`, `checkpoint`, `index` |
| `shared/rules/*.md` | Discipline: workflow, severity, ship-gates, tdd, research, approach-comparison, memory, docs-layout, continuity, models, project-rules |
| `PROJECT.md` | Project-specific persona / info / variables / special rules (editable) |
| `CONTINUITY.md` | Session handoff (focus · next step · blockers) |
| `.claude/` · `.codex/` · `opencode.json` | Per-engine config + native push/PR gates; `skills/` symlinked into each |
| `docs/` | `prds/ plans/ research/ solutions/ adr/` + `CHANGELOG.md`, `extending.md`, `index.md` |
| `*.template.md` | Blanks: `state`, `CONTINUITY`, `PROJECT` |
| `install.sh` | Copy-based installer |

## Conventions

- **One canonical source:** `AGENTS.md` → `CLAUDE.md` symlink; `skills/` symlinked into
  `.claude/`, `.codex/`, `.opencode/`.
- **`SKILL.md`:** the directory name must equal the frontmatter `name`; filename uppercase.
- **Tiers** (`docs/extending.md`): A = skills-only · B = skills + scripts · C = hooks.
  Prefer the lowest tier that works.
- **Enforcement:** advisory + native push/PR approval (no hard conditional blocking).
- **Never use git worktrees** — simple branch only.
