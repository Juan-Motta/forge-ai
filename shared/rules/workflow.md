# Workflow

Use a workflow skill for any non-trivial change. Follow its steps in order.

## Which skill

| Scenario | Skill |
| --- | --- |
| New feature / behavior change | `new-feature` |
| (future) Bug fix | `fix-bug` |
| (future) Trivial change (<3 files) | `quick-fix` |
| (future) Wrap up + open PR | `finish-branch` |

## Phases (shared shape)

1. **Brainstorm** — clarify intent, constraints, success criteria before designing.
2. **Plan** — write the approach; identify files, edge cases, tests.
3. **Design review** — get a second opinion from the *other* engine (Codex reviews
   Claude's plan, or Claude reviews Codex's) before implementing. Cross-engine diversity
   is the point.
4. **TDD** — red → green → refactor. Write the failing test first.
5. **Code review** — dual review (the other engine + self) against the diff; fix all
   P0/P1/P2 before shipping (see `severity.md`).
6. **Verify** — actually exercise the change, don't just trust tests.
7. **Ship** — only when `.workflow/state.md` gates pass (see `ship-gates.md`).

## Tracking

Keep `.workflow/state.md` current: check boxes as phases complete, record the active
branch and the review iterations. It is the source of truth the ship-gate checklist reads.
