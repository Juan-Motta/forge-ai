# ADR 001 — Commit CONTINUITY.md to git

- **Status:** Accepted — 2026-07-15
- **Deciders:** council (Codex `gpt-5.6-sol`, Claude `opus`, OpenCode `opencode-go/glm-5.2`) + maintainer

## Context

`CONTINUITY.md` is the session-handoff file (current focus, next step, blockers). It
changes almost every session (high churn) and is somewhat session-specific, but continuity
must survive a fresh clone / a different machine / a different engine. `.workflow/state.md`
(the workflow checklist) is a separate file. The repo is solo-owned for now but lives on
GitHub. Question: **commit it (shared history) or gitignore it (local per-machine)?**

## Decision

**Commit `CONTINUITY.md` to git.** Keep it small — the template (`CONTINUITY.template.md`)
enforces a handful of lines.

## Rationale

The file's whole purpose is continuity across session resets / clones / engines.
Committing delivers that with **zero extra infrastructure**, consistent with the project's
"simplest, no scripts, portable" principle. Gitignoring would require a sync path (gist /
dotfiles) — reintroducing infrastructure the project deliberately avoids. Churn is cheap
for a solo/small repo and is controlled by keeping the file tiny.

## Council record

| Advisor | Lens | Position |
| --- | --- | --- |
| Codex `gpt-5.6-sol` | longevity | A — commit |
| OpenCode `glm-5.2` | simplicity | B — gitignore (continuity is state, not history; churn/merge noise) |
| Claude `opus` (chairman) | risk / reversibility | A — commit |

**Verdict 2–1: A (commit).**

## Consequences & minority report

Accepted risk (OpenCode dissent, B): with **multiple active collaborators**, a committed
`CONTINUITY.md` becomes merge-conflict-prone and adds `git log` noise.

**Revisit trigger:** more than one active committer → migrate to gitignore + a sync path,
or make it per-user (`CONTINUITY.<user>.md`) / move it to a gitignored `.workflow/`.
