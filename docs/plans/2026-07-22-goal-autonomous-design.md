# codeforge `/goal` — autonomous mode (Fase 2) — design spec

**Written:** 2026-07-22. **Branch:** `feat/goal-autonomous` (off `dev`, v0.6.0).
**Status:** design approved in brainstorming; awaiting spec review → writing-plans.

Repo: `~/Desktop/personal/projects/forge-ai` (GitHub `Juan-Motta/codeforge`, npm
`@jualopezmo/codeforge`). Cross-engine (Claude Code / Codex / OpenCode) workflow-discipline
framework. This spec designs the `/goal` autonomous skill — the top remaining capability gap
vs the origin project `claude-codex-forge`. Cross-engine `/goal` makes codeforge's version
**unique** (the origin's is Claude+Codex only).

---

## 1. Goal

Add a resumable, mostly-autonomous workflow driver that takes a single objective from idea to
a PR-ready branch — `prd → research → plan → review → TDD → review → verify → PR` — pausing for
the human at **only two** planned points (entry approval + PR creation). Everything in between
runs autonomously; genuinely ambiguous forks route to the `council` skill instead of pausing;
non-convergence halts for a human.

It must run **identically under Claude Code, Codex, and OpenCode**, and it must be **honest**:
the autonomy is skill-level discipline plus the existing Attested `check-gates` checkpoint — it
is **not** a runtime hard gate. The only real hard gate remains the Fase 1 CI template over the
PR merge result.

### Non-goals (YAGNI)

- No new hook/enforcement mechanism. `--with-hooks` was retired in Fase 1 and stays retired.
- No re-implementation of phase logic already owned by existing skills (`prd`, `research`,
  `plan`, `new-feature`, `fix-bug`, `review`, `simplify`, `verify-e2e`, `finish-branch`).
- No dedicated third state file — the loop state lives in the existing `.workflow/state.md`.
- No auto-approval of `ask`-tier prompts (an autonomous loop cannot, by design).

---

## 2. Decisions locked in brainstorming

| # | Fork | Decision |
| - | ---- | -------- |
| 1 | Enforcement posture of the loop's safety gates | **Discipline + `check-gates` (Attested), cross-engine, honest.** No new hooks. Safety gates are documented instructions; the spec/skill state plainly they are not runtime-enforced across the three engines. |
| 2 | Durable resume of loop progress | **Reuse `.workflow/state.md` (new `## /goal loop` section) + `CONTINUITY.md`.** No new files. |
| 3 | Human pause points | **Entry (PRD/plan approval) + PR creation only.** Ambiguous → `council`; non-convergence → human halt. |

Defaults inherited from the origin's model and existing codeforge rules (applied, not re-asked):
council triggers, convergence-breaker as a discipline counter, per-engine execution via
`execution.md`, failure handling via retry→council-or-halt.

### Chosen approach: **A — orchestrator that composes existing skills**

`/goal` is a thin engine-neutral `SKILL.md` the driver follows. It does not duplicate skill
content (rejected approach B — DRY violation + linter index-parity friction + drift risk) and it
keeps an explicit phase state machine (rejected approach C — a bare wrapper has no explicit phase
ledger, but decision #2 requires one for resumability).

---

## 3. Architecture

`/goal <objetivo>` → new file `src/skills/goal/SKILL.md`, engine-neutral. The driver follows it,
calling existing skills in sequence and advancing the phase machine in `.workflow/state.md`.

```
/goal <objetivo>
  → classify: feature vs bug (reuse workflow.md criteria) → new-feature | fix-bug
  → prd            (feature only; fix-bug uses its reproduce/root-cause instead)
       ──GATE 1 (human): approve PRD/plan──┐
  → research       (only if external tech) │
  → plan + design review (cross-engine     │
       loop until clean)                   │ autonomous
  → TDD            (execution.md: subagent  │  (ambiguous fork → council;
       on Claude / inline on Codex+OpenCode)│   non-convergence → human halt)
  → code review (cross-engine loop clean)   │
  → simplify       (while green)            │
  → verify-e2e     (or honest N/A)          │
  → finish-branch                           │
       ──GATE 2 (human): create PR──────────┘
```

The classification (feature vs bug) reuses the existing `workflow.md` "Which skill" table logic;
`/goal` does not invent new routing. For a feature it drives the `new-feature` phase sequence;
for a bug, the `fix-bug` sequence (which may skip the plan-review phase for a simple 1–2 file
fix, per that skill).

---

## 4. State machine — `## /goal loop` in `.workflow/state.md`

New section appended to the state template, with **REPLACE semantics** (the whole section —
heading + table — is overwritten atomically on each new kickoff; a stale loop is never appended
to). Mirrors the origin's `## /goal session` pattern.

```
## /goal loop

| Field     | Value                                             |
| --------- | ------------------------------------------------- |
| nonce     | <uuid-v4-lowercase>                               |
| goal      | <one-line objective>                              |
| workflow  | new-feature <name> | fix-bug <name>               |
| phase     | prd|research|plan|plan-review|tdd|code-review|verify|ship |
| issued_at | <ISO-8601-UTC>                                    |
```

- **Active definition:** the loop is ACTIVE when the `nonce` row holds a UUID. A heading with no
  nonce row, or a missing section, is INACTIVE.
- **Review-iteration counters** live in the existing `## Review log` section (not duplicated
  here) — plan-review and code-review iterations each recorded as they happen.
- **PR authorization** is recorded per the existing gate convention (a `## /goal loop`-adjacent
  authorization line carrying nonce + current HEAD SHA), written only after GATE 2 approval.
- **Resume:** on a new session or after compaction, read `.workflow/state.md` **with the Read
  tool** (never Bash — it trips the sensitive-file prompt) and `CONTINUITY.md`; continue from the
  recorded `phase`. **Never restart a completed phase** (the SDD progress-ledger lesson).
- `CONTINUITY.md` carries the cross-session narrative, written via the existing `checkpoint`
  skill before a context reset.

---

## 5. Human gates + council routing

### GATE 1 — entry (PRD/plan approval)
After `prd` (feature) or the plan (bug), the driver **pauses** and asks the human to approve
before the autonomous run begins. On Claude Code this is `AskUserQuestion`; on Codex/OpenCode a
plain in-conversation approval prompt.

### GATE 2 — PR creation
`finish-branch` reaches `git push` / `gh pr create` → **pause**. On Claude Code the driver calls
`AskUserQuestion` (the only human-authority signal in the loop); on Codex/OpenCode the native
`ask`-tier permission prompt (`.codex/config.toml` / `opencode.json`) serves the same role. A PR
authorization line is written to `.workflow/state.md` (nonce + HEAD SHA) so a later HEAD change
invalidates it.

### Council instead of pausing (during the autonomous middle)
The driver invokes the `council` skill — not the human — when:
- an ambiguous product or technical choice would otherwise prompt the user;
- a reviewer recommends **revising the plan** (not merely patching code);
- a high-impact implementation fork has multiple defensible approaches;
- a retried tool/subagent has **also** failed and the recovery is a judgment call;
- reviewer/council output is unrecognizable and needs interpretation.

### Explicit NON-triggers (never council, never auto-pause)
- Normal plan-review-loop iterations (driver ↔ reviewer back-and-forth on the plan).
- Normal code-review-loop iterations (reviewer + self-pass fix cycles).
- **Non-convergence** → **human-only HALT** (council is never the autonomous risk-acceptor).

### Council failure handling
If `council` itself fails (advisor timeout, missing verdict), the loop **pauses** and writes a
line to `## Blockers` in `.workflow/state.md`; the human takes over.

---

## 6. Cross-engine review loop + convergence breaker (discipline)

Reuse the existing `review` skill (reviewer ≠ driver; **Codex mandatory** per `models.md`; add
OpenCode/other advisors where available). Two loops:

- **Plan-review loop** (design phase): exit only when no reviewer reports P0/P1/P2 on the same
  pass. Record each iteration in `## Review log`.
- **Code-review loop** (post-TDD): reviewer(s) + a self-pass over the diff; exit on the same
  no-P0/P1/P2 condition. Then `simplify` while green.

**Convergence-breaker (discipline, not a hook):** define *certification* = the first pass where
all available reviewers are clean at the same HEAD. If more than **3** further rounds occur past
certification, the driver **HALTs for a human** and writes the reason to `## Blockers`. Release is
**human-only**: the human writes an adjudication line (head-bound; a new commit invalidates it).
The driver never writes that line on its own initiative.

**Honesty note (must appear in the skill body):** unlike the origin project, codeforge does **not**
enforce this breaker with a hook — it is skill-level discipline. The only runtime-hard gate is the
Fase 1 CI template over the PR merge result. Say so plainly; claim no more than is delivered.

---

## 7. Per-engine execution + failure handling

- **Execution mode** per `execution.md`: **subagent-driven on Claude Code** (dispatch the
  generated `codeforge-implementer` agent per task; driver reviews between tasks); **inline** on
  Codex/OpenCode (they have no cross-engine subagent mechanism). `/goal` never changes the
  engine-neutral core — the same plan runs inline everywhere else.
- **Tool/subagent failure:** retry once → if still failing and recovery is a judgment call,
  invoke `council`; otherwise **HALT** with a `## Blockers` line and hand to the human.
- **`ask`-tier commands (`rm -rf`, etc.):** an autonomous loop **cannot** self-approve the native
  permission prompt, so such a command silently stalls the run. The skill instructs the driver to
  **avoid** ask-tier commands when a prompt-free alternative exists (cache flags, `: >` truncation
  instead of `rm`, etc.), and to announce it explicitly when a recursive delete is unavoidable so
  the stall is expected, not silent. (Mirrors the origin `workflow.md` guidance.)

---

## 8. Enforcement model (honest — the identity)

At each phase transition the driver runs `shared/scripts/check-gates.sh` (Attested tier,
identity-checked since Fase 0) as a deterministic checkpoint that the prior phase left its
required ship-gate boxes green. The skill states, in its body and a dedicated honesty block:

> This autonomy is **discipline plus an Attested checkpoint**, not a runtime hard gate. On all
> three engines the only bad-faith-resistant hard gate is the Fase 1 CI template
> (`docs/ci-templates/gates.yml`) rerunning the declared tests on the PR merge result with branch
> protection. `/goal` does not, and cannot, block a bad ship locally.

This keeps `/goal` consistent with codeforge's Advisory/Attested/Verified ladder
(`shared/rules/ship-gates.md`) and its "honest enforcement" wedge.

---

## 9. Landing checklist (linter / evals / tests)

- `src/skills/goal/SKILL.md` — full **anti-rationalization anatomy**: `## Common rationalizations`
  + `## Red flags` + `## Verification` sections (HARD-required by `tools/lint-skills.mjs`).
  `name: goal`, `description:` following the existing skills' shape (must route well in evals).
- `src/CLAUDE.md` — add `goal` to the "Workflow skills" index list (index parity is a linter hard
  error).
- `tools/run-evals.mjs` fixture — add routing/collision cases for `/goal` (rank-1 ≥ floor); make
  sure it doesn't collide with `new-feature`/`fix-bug`.
- `src/shared/state.template.md` — add the `## /goal loop` section (INACTIVE by default:
  heading + empty-value table, matching how `## /goal session` ships in the origin's template).
- `src/shared/rules/workflow.md` — add a `/goal` row to the "Which skill" table and a short
  "autonomous run" note (human gates, council routing, honest non-enforcement).
- Tests (`tools/test/*.test.mjs`, `node --test`, zero-dep): cover any new parsing helper for the
  `## /goal loop` REPLACE semantics if one is added; assert the skill file passes the linter and
  the evals fixture routes `/goal` rank-1. Installer smoke (`tests/smoke.sh`) already asserts the
  skill dir is copied — extend the expected-skills list to include `goal`.
- `docs/CHANGELOG.md` — add the feature under `## Unreleased` (ships with the next release; per
  the user's instruction this stays on v0.6.0, no separate release cut for it now).

---

## 10. Open questions for spec review

- Should `/goal` support a `fix-bug` objective end to end in v1, or ship **feature-only** first
  and add the bug path in a follow-up? (Feature path exercises the full PRD gate; the bug path
  reuses `fix-bug`'s reproduce/root-cause and may skip plan-review — slightly different gate map.)
- Exact wording of GATE 1 for the three engines (Claude `AskUserQuestion` modal vs Codex/OpenCode
  text prompt) — align with how the origin phrases PRD approval.
- Whether the convergence-breaker counter needs a helper for auditability, or a plain
  `## Review log` line convention is enough (leaning: plain convention — hooks-light).

---

## 11. How this proceeds (process)

1. Spec review by the human (this file), then adjust inline.
2. `superpowers:writing-plans` → implementation plan (task list + test stubs).
3. **Cross-engine plan review** (Opus + Codex `gpt-5.6-sol` + OpenCode `kimi-k3`) — it caught real
   structural problems twice already this project; mandatory here.
4. `superpowers:subagent-driven-development` — per-task impl + review; final whole-branch review
   (Opus READY + Codex CLEAN) before PR.
5. PR `feat/goal-autonomous` → `dev`. Stays on v0.6.0 (no release cut now, per user).

Reference to study before writing the plan: the origin's `/goal` (`~/Desktop/personal`'s
`.claude/commands/goal.md` + `.claude/rules/workflow.md` "Council During /forge-goal Autonomous
Run"), and codeforge's own `new-feature`/`fix-bug`/`review`/`council`/`finish-branch` skills +
`execution.md`, `ship-gates.md`, `models.md`.
