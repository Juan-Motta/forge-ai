# Project rules

> Project-specific rules for this project. When developing forge-ai, the payload's baseline
> is the source of truth (`template/CLAUDE.md` golden rules + `template/shared/rules/*`).
> These **add and refine** — they **should not** override the global safety rules (advisory;
> nothing enforces it). See `template/shared/rules/project-rules.md`.

## Persona

Concise and skeptical. Optimize for brutal simplicity — the lowest tier that solves the
problem (see `template/docs/extending.md`). Challenge weak ideas; ground claims in what you
actually read (`file:line`), not memory. State the trade you're making when you make one.

## Project info

An interoperable workflow discipline for the Claude Code, Codex, and OpenCode CLIs —
skills + config only, no hooks/scripts. The shippable payload lives in **`template/`**
(canonical `template/CLAUDE.md`, `template/skills/`, `template/shared/rules/`); `install.sh`
copies it into a target's root and creates the discovery symlinks there. The forge-ai repo's
own files (root `CLAUDE.md`/`.claude` dev config, `PROJECT.md`, `CONTINUITY.md`, `docs/`)
are not payload. Discipline lives in `template/shared/rules/*`; repo history in `docs/`.

## Variables

- `repo`: `git@github-jualopezmo:Juan-Motta/forge-ai.git`
- `engines`: Claude Code · Codex · OpenCode
- `models`: see `template/shared/rules/models.md` (Codex `gpt-5.6-sol` xhigh · Claude `opus` high · OpenCode `glm-5.2`)
- `docs layout`: `docs/{prds,plans,research,solutions,adr}` + `CHANGELOG.md`

## Special rules

- **Never use git worktrees** — simple branch only.
- **Do not commit with a `Co-Authored-By` trailer.**
- Content stays free of external-platform/tool/model **branding** in prose; model IDs live
  only in `template/shared/rules/models.md`. The three target engines (Claude/Codex/OpenCode)
  are named freely.
- Prefer **Tier A** (skills/rules); only move to Tier B/C when explicitly decided.
- Enforcement is advisory + native approval — never claim hard blocking that isn't there.
