# /goal Plan C — the `/goal` orchestrator skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or
> superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Goal:** Ship the `/goal` skill itself — the engine-neutral orchestrator that drives a single
feature objective `prd → research → plan → tdd → review → simplify → verify → ship` mostly
autonomously (two human gates: entry + PR), consuming Plan A's helpers and Plan B's `owner=goal` /
`commit_policy=defer` contract. Plus its catalog wiring: `src/CLAUDE.md` index entry, the routing
eval case, the `workflow.md` row, the `## Blockers` / `## Attempts` state-template sections, and a
smoke check that the helpers ship.

**Architecture:** `/goal` is a `SKILL.md` the driver follows (no runtime engine). It distills the
design spec (`docs/plans/2026-07-22-goal-autonomous-design.md`, rev5) into operational instructions
+ the §11 state machine. It never re-implements the composed skills — it invokes them under
`owner=goal`. All artifacts are engine-neutral `src/` files validated by `npm run check` (lint +
evals) and `tests/smoke.sh`.

**Tech Stack:** Markdown skill/rules, JSON eval fixture, `sh` smoke test.

## Global Constraints

- The skill linter (`tools/lint-skills.mjs`) HARD-requires, for `goal/SKILL.md`: valid frontmatter
  (`name: goal`, a `description:` with a trigger clause, within length), `name` == dir, a
  `src/CLAUDE.md` index entry (parity — both or neither), no hard-coded model ids, valid `shared/`
  references, and the anti-rationalization anatomy (`## Common rationalizations` + `## Red flags` +
  `## Verification`). These must all land in the SAME task or lint fails.
- The routing evals (`tools/run-evals.mjs`) HARD-require a `goal` entry in `routing-cases.json`
  (coverage), `goal` ranking top-3 on its positives (rank-1 floor 70%), and **no description
  collision ≥0.75 with `new-feature`** — so `goal`'s description must emphasize its DISTINCTIVE
  trait (autonomous / hands-off / unattended, human pauses only at approval + PR), not just "build a
  feature end to end" (which is `new-feature`).
- v1 is feature-only: `/goal` REJECTS a bug objective and routes the human to `/fix-bug`.
- The skill body must faithfully carry the spec's load-bearing rules: capability preflight (§6.4,
  incl. the stale-agent HALT from Plan B), the two explicit human gates (§5), commit-before-GATE-2
  ship ordering (§8), bounded review loops + `simplify`-once + cross-phase re-entry (§6), the
  `## /goal loop` state + resume (§4), and the honesty block (§8).
- `npm run check` and `sh tests/smoke.sh` green after the relevant tasks.

---

## File Structure
- `src/shared/state.template.md` — add `## Blockers` + `## Attempts` (Task 1).
- `src/skills/goal/SKILL.md` — the orchestrator skill (Task 2).
- `src/CLAUDE.md` — index entry for `goal` (Task 2).
- `tools/evals/routing-cases.json` — `goal` positive/negative cases (Task 2).
- `src/shared/rules/workflow.md` — `/goal` row + autonomous-run note (Task 2).
- `tests/smoke.sh` — assert `shared/scripts/goal-{digest,state}.{sh,ps1}` ship (Task 3).

---

### Task 1: `state.template.md` — add `## Blockers` and `## Attempts`

**Files:** Modify `src/shared/state.template.md`.
**Interfaces:** the sections `goal-state.sh` / the `/goal` skill read & write (§10). `## /goal loop`
is intentionally ABSENT by default (its absence = inactive — §4).

- [ ] **Step 1: Append the two sections** after `## Notes` (currently the last section):

```markdown

## Blockers

<!-- HALT records written by /goal (design §10). Empty when nothing is halted.
     Unresolved:  - [ ] BLOCKER <id> — <phase> — <reason> — ts=<ISO>
     A human resumes only after resolving every open blocker. -->

## Attempts

<!-- Durable retry counters written by /goal (design §10). Empty by default.
     - ATTEMPT ship-red — n=<k> — ts=<ISO>   (n>=2 → /goal HALTs) -->
```

- [ ] **Step 2: Verify + commit.**
  `npm run check` (PASS — the template isn't a skill; lint doesn't object) →
  `git add src/shared/state.template.md` →
  `git commit -m "feat(goal): state template gains ## Blockers + ## Attempts sections"`

---

### Task 2: the `/goal` skill + catalog wiring (lands together for lint/eval parity)

**Files:** Create `src/skills/goal/SKILL.md`; modify `src/CLAUDE.md`,
`tools/evals/routing-cases.json`, `src/shared/rules/workflow.md`.

- [ ] **Step 1: Add the eval case first** (so you can red→green the routing) — add to
  `tools/evals/routing-cases.json` under `"skills"`, and mind the **collision guard** (distinct
  from `new-feature`):

```json
    "goal": {
      "positive": [
        "drive this feature from idea to a PR on your own, only check with me to approve the plan and the PR",
        "run the whole workflow autonomously and hand me a PR-ready branch — don't wait on me between steps",
        "take this objective and do prd, plan, tests, review, and verify hands-off until it's ready to ship"
      ],
      "negative": [
        { "prompt": "build the CSV export feature end to end with tests and review", "owner": "new-feature" },
        { "prompt": "the invoice totals are wrong, reproduce and fix the defect", "owner": "fix-bug" },
        { "prompt": "compare two designs and write the plan", "owner": "plan" }
      ]
    }
```

- [ ] **Step 2: Write `src/skills/goal/SKILL.md`**

````markdown
---
name: goal
description: Drive one feature objective autonomously from idea to a PR-ready branch — prd → plan → TDD → cross-engine review → verify → ship — pausing for a human only to approve the PRD and to create the PR. Use when you want the whole workflow run hands-off/unattended under Claude Code, Codex, or OpenCode; everything between the two gates the agent decides itself.
---

# goal

Orchestrate one **feature** objective end to end with only two planned human pauses (approve the
PRD; create the PR). Between them it runs autonomously: ambiguous forks go to `council`, not to the
human; non-convergence and unrecoverable failure HALT for a human. It composes the existing skills
under `owner=goal` (`shared/rules/execution.md`) — it never re-implements them — and advances the
state machine in `.workflow/state.md` (`## /goal loop`).

**Honesty:** this autonomy is discipline plus a terminal Attested checkpoint (`check-gates` at
ship), not a runtime hard gate. Intermediate progress is Advisory. On all three engines the only
bad-faith-resistant gate is the fully-activated Fase 1 CI template. `/goal` cannot block a bad ship
locally — it only automates the discipline.

## 0. Classify + capability preflight (before any human gate)

1. **Classify** the objective. If it is a **bug**, STOP and tell the human to run `/fix-bug` — v1
   `/goal` is feature-only. Only a feature objective proceeds.
2. **Clean slot** (`shared/rules/execution.md`): if `.workflow/state.md` shows a non-`done`
   `## /goal loop` OR any other unfinished workflow, STOP and ask the human to disposition it — no
   cross-session resume, and never reset a live checklist. A `halted` loop is never auto-resumed.
3. **Capability preflight** — prove, on the driver engine:
   - a non-driver reviewer engine is available (`shared/rules/models.md`; pick a different engine if
     the default equals the driver);
   - spawning the reviewer/council CLI **and** the post-GATE-2 `git push` / `gh pr create` are
     prompt-free under the current permission config (else the "two pauses" claim is false);
   - reviewer/council output goes to stdout or under `.workflow/` (so it can't move the digest);
   - **(Claude subagent-driven only)** `.claude/agents/codeforge-implementer.md` exists and contains
     `commit_policy` — a stale pre-`commit_policy` agent would commit mid-loop; if missing/stale,
     HALT and tell the human to re-run codeforge setup;
   - the digest is stable across one test-suite run (`shared/scripts/goal-digest.sh` before/after a
     test run over a scratch state; if it moves, HALT naming the unignored generated paths).
   Any failure → HALT before GATE 1 (`## Blockers`); never degrade to per-round prompting or driver
   self-review.
4. Initialize `## /goal loop` (REPLACE), reset the standard `## Ship-gate checklist` to unchecked,
   record `base_sha` (merge-base) and `reentries=0`.

## 1. PRD → GATE 1 (human, explicit)

Run `prd`. Then set `status=awaiting-gate1` and ask the human to approve the PRD **explicitly**
(`AskUserQuestion` on Claude; a plain approval prompt on Codex/OpenCode). On approval, write the
`gate1` record (`shared/rules/…` §10: `approved ts + prd path`) and `status=active`. Do not enter
the autonomous middle without a `gate1` record.

## 2. Autonomous middle (no human pauses; council for forks)

Drive, in order, advancing `phase` in `## /goal loop`:

- **research** (only if external tech) — the `research` skill.
- **plan-review loop** — `/goal` runs the `plan` skill for the plan, then orchestrates `review`
  over the plan doc (reviewer ≠ driver). `/goal` owns the loop + logging: append a §10 review-log
  line per round; **certification** = a pass where the expected-reviewer set is clean at one
  digest; HALT if not certified within `N` rounds (`N=4`).
- **tdd** — implement per `shared/rules/execution.md` with **`commit_policy=defer`** (implementers
  stage only, never commit; `/goal` writes the `step` cursor after each accepted task).
- **code-review loop** (bounded, re-entrant — the heart):
  - review rounds (reviewer + a self-pass) → **first clean pass** → run `simplify` **exactly once**
    (record the SIMPLIFY marker) → **one re-cert pass** at the post-simplify digest → certify.
  - Breaker: HALT if a loop's `kind=round` count reaches `N`. Global cap: HALT if `reentries >=
    MAX_REENTRIES` (3) or total code-review rounds `>= MAX_CODE_ROUNDS` (3·N).
- **verify** — the `verify-e2e` skill (or an honest `N/A`). **Any post-certification change to a
  digest-covered path invalidates certification**: increment `reentries` and re-enter code-review
  (simplify does not re-run).
- **Ambiguity** (product/technical fork, a reviewer wanting a plan revision, a retried subagent that
  also failed, unrecognizable reviewer output) → invoke `council`, apply its verdict, continue.
  Non-convergence / unrecoverable failure / an unavoidable `ask`-tier command → HALT (`## Blockers`,
  `status=halted`); the human takes over (no autonomous release).

## 3. Ship → GATE 2 (human, explicit)

Compute the digest and run `check-gates`. Then, in this exact order (`shared/rules/ship-gates.md`):

1. `check-gates` green AND `digest(worktree) == certification digest`;
2. write the CHANGELOG (digest-neutral) + tick the ship-gate checklist boxes (verify writes the
   E2E report path into its box);
3. **single commit** (stage the digest-covered set ∪ CHANGELOG + the E2E report);
4. assert `digest(committed tree) == certification digest` (`goal-digest.sh --from-head`) AND the
   report + CHANGELOG are in HEAD — mismatch → HALT (never GATE 2 over an unproven commit);
5. `status=awaiting-gate2` → ask the human to approve the PR **explicitly** (all engines) → write
   the `gate2` authorization line (nonce/action/committed-head/branch/remote) → re-verify the head
   → push → open the PR → `status=done`.

If the human declines / requests changes → soft-reset the unpushed commit, return to the owning
phase (a code change re-enters code-review). The native push/PR prompt is defense-in-depth only.

## 4. State + resume

`## /goal loop` (`goal | status | phase | step | reentries | base_sha | gate1`) is the source of
truth; `## Blockers` / `## Attempts` hold HALT records and the durable ship-red counter
(`shared/scripts/goal-state.sh`). On a mid-session compaction, re-orient from the summary + a Read
of `## /goal loop` and continue from `phase`/`step` — never restart a completed phase, never enter
the middle without a valid `gate1`. `status=halted` → stop; the human resumes after resolving the
blockers. This is best-effort in-session continuity, not durable cross-session resume (v2).

## Common rationalizations

| Rationalization | Reality |
| --- | --- |
| "It's basically a feature — I'll let /goal handle a bug too." | v1 is feature-only. A bug has no PRD gate and a different phase map; route the human to `/fix-bug` instead of half-driving it. |
| "Preflight is ceremony — just start; I'll approve prompts as they come." | An autonomous loop can't approve a native prompt — it silently stalls. If reviewer/push spawns aren't prompt-free, HALT now, honestly, rather than hang later. |
| "The reviewer looked fine; skip counting rounds." | The breaker is the only thing bounding a non-converging loop. Count `kind=round` and HALT at N — an unbounded review loop burns the run. |
| "Commit per task so progress is saved." | Under `/goal`, implementers use `commit_policy=defer` — a mid-loop commit violates ship-gates' no-commit-before-green. `/goal` makes the single commit at ship. |
| "Just push after the gates — the native prompt is the approval." | GATE 2 is an explicit driver-issued approval; the native prompt is bypassable and not the gate. Commit first, then get explicit approval, then push. |

## Red flags

- A bug objective being driven through the feature machine.
- Entering the autonomous middle without a `gate1` record, or after a failed preflight.
- A review loop with no `## Review log` rounds, or running past N/MAX with no HALT.
- An implementer committing during `tdd` (should be `commit_policy=defer`).
- GATE 2 authorized before the single commit, or a push with no explicit human approval.
- Claiming more autonomy/safety than delivered (see the honesty block).

## Verification

- [ ] Objective classified; a bug was routed to `/fix-bug`, not driven here.
- [ ] Capability preflight passed (or HALTed honestly) before GATE 1.
- [ ] Exactly two explicit human gates fired (PRD approval; PR creation); everything else was
      autonomous or a council call.
- [ ] Review loops bounded (certification or a HALT at N/MAX); `simplify` ran at most once.
- [ ] Single commit made BEFORE GATE 2; committed-tree digest == certification digest.
- [ ] `## /goal loop` reflects the real phase; no completed phase was restarted on resume.
````

- [ ] **Step 3: Add the index entry** to `src/CLAUDE.md` "## Workflow skills" list (after
  `finish-branch`, keeping the file's ordering sensible):

```markdown
- `goal` — drive one feature objective autonomously (prd → plan → TDD → review → verify → ship) with only two human gates (approve PRD, create PR); orchestrates the other skills, doesn't replace them
```

- [ ] **Step 4: Add the `workflow.md` row + note.** In `src/shared/rules/workflow.md` "Which skill"
  table add:

```markdown
| Drive a whole feature hands-off (idea → PR-ready) | `goal` |
```

  and a short paragraph after the table:

```markdown
`goal` is an **orchestrator**: it runs the skills above under `owner=goal` (see `execution.md`),
pausing for a human only to approve the PRD and to create the PR. It is feature-only in v1 (a bug
objective is routed to `fix-bug`). Its autonomy is discipline, not a runtime gate — see the honesty
note in the `goal` skill.
```

- [ ] **Step 5: Verify (lint + evals) + commit.**

Run: `npm run check`
Expected: PASS — specifically: skill-lint clean (anatomy + index parity for `goal`), and
run-evals: `goal` covered, ranks top-3 on its positives, its negatives outranked by
new-feature/fix-bug/plan, **no collision ≥0.75 with new-feature**, rank-1 ≥ 70%. If a
`goal ~ new-feature` collision or a misroute appears, sharpen the `description` toward the
autonomous/hands-off distinction (not the "build a feature" overlap) and re-run.

```bash
git add src/skills/goal/SKILL.md src/CLAUDE.md tools/evals/routing-cases.json src/shared/rules/workflow.md
git commit -m "feat(goal): the /goal orchestrator skill + index + eval case + workflow row"
```

---

### Task 3: smoke — assert the helpers ship to targets

**Files:** Modify `tests/smoke.sh`.

- [ ] **Step 1: Add the helpers to the runtime-file check.** In the bash-install file loop
  (`tests/smoke.sh:33-37`), add to the list:

```
         shared/scripts/goal-digest.sh shared/scripts/goal-state.sh \
         shared/scripts/goal-digest.ps1 shared/scripts/goal-state.ps1 \
         .claude/skills/goal/SKILL.md \
```

- [ ] **Step 2: Run smoke.**

Run: `sh tests/smoke.sh`
Expected: PASS — the installer copies `shared/scripts/*` and `skills/*` into the target, so the
`goal-*` helpers and the `goal` skill are present. (If the skill/helpers aren't copied, the
installer/sync glob needs checking — but `check-gates.{sh,ps1}` in the same dir already ships, so
the helpers ride along; the `goal` skill ships like every other `src/skills/*`.)

- [ ] **Step 3: Full check + commit.**

Run: `npm run check` (still green) and `sh tests/smoke.sh` (green).

```bash
git add tests/smoke.sh
git commit -m "test(goal): smoke-verify goal helpers + skill ship to targets"
```

---

## Self-Review

**Spec coverage (Plan C scope):**
- §3 architecture + classify/reject-bug + preflight → SKILL.md §0. ✓
- §4 state machine + resume → SKILL.md §4 + Task 1 template sections. ✓
- §5 two explicit gates → SKILL.md §1 (GATE 1) + §3 (GATE 2). ✓
- §6 bounded loops + simplify-once + cross-phase re-entry + preflight → SKILL.md §0/§2. ✓
- §6.4 preflight incl. **stale-agent HALT** (Plan B dependency) → SKILL.md §0.3. ✓
- §7 commit_policy=defer → SKILL.md §2 (tdd). ✓
- §8 ship ordering (commit before GATE 2) + honesty block → SKILL.md §3 + honesty block. ✓
- §9 landing: goal/SKILL.md, CLAUDE.md index, evals, workflow row, ## Blockers/## Attempts,
  smoke → Tasks 1–3. ✓
- Feature-only + bug rejection → SKILL.md §0.1 + the eval negative + `## Common rationalizations`. ✓

**Placeholder scan:** the SKILL.md is complete operational prose; supporting edits have exact
content. No TBD.

**Lint/eval risk (flagged):** the `goal ~ new-feature` collision is the one real risk. The
description leads with "autonomously … pausing for a human only to approve the PRD and to create the
PR … hands-off/unattended" — deliberately distinct from new-feature's "build … end to end with
tests and review". If run-evals still flags a collision ≥0.75 or a misroute, Task 2 Step 5 says to
sharpen the description toward the autonomy distinction; that is expected iteration, not a redesign.

**Consistency:** the SKILL.md references only existing shared rules/scripts (`execution.md`,
`models.md`, `ship-gates.md`, `goal-digest.sh`, `goal-state.sh`) — all landed in Plans A/B. The
`commit_policy=defer` / `owner=goal` usage matches Plan B's contract; the digest/`--from-head` usage
matches Plan A's helper.
````
