# Workflow State — <feature-name>

> Copy this file to `.workflow/state.md` when a workflow starts. It is the source of truth
> the ship-gate reads. Keep it updated as you progress.

## Active workflow

- **Skill:** new-feature
- **Feature:** <name>
- **Branch:** <feat/...>
- **Driver:** <claude | codex>
- **Phase:** <brainstorm | plan | design-review | tdd | code-review | verify | ship>

## Ship-gate checklist

- [ ] On a feature branch (not `main`)
- [ ] Plan written and design-reviewed by the other engine
- [ ] Tests written (TDD) and passing
- [ ] Code review clean — no open P0/P1/P2
- [ ] Change verified by exercising it
- [ ] State updated

## Review log

- Design review iteration 1 — <engine> — findings: <P0/P1/P2 counts or "clean">
- Code review iteration 1 — <engine> — findings: <...>

## Notes

<decisions, assumptions, what was verified>
