# /goal Plan B — composition plumbing (execution.md + generated agent + owner=goal notes)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or
> superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Goal:** Make the existing composed skills safe to drive under `/goal` — teach `execution.md` the
`owner` + `commit_policy=per-task|defer` contract, make the wizard-generated `codeforge-implementer`
agent honor `commit_policy` (stage-only, no commit, under `defer`), and add `owner=goal` notes to
`plan` / `review` / `new-feature` / `finish-branch` so their standalone init/ship/self-loop steps
are disabled when `/goal` owns the loop.

**Architecture:** All engine-neutral prose/config in `src/`, plus one JS generator change
(`cli/lib/apply.mjs`) with a test. No runtime behavior change for non-`/goal` use: `commit_policy`
defaults to `per-task` (today's behavior); `owner` defaults to standalone. Only `/goal` (Plan C)
passes `commit_policy=defer` / `owner=goal`.

**Tech Stack:** Markdown skills/rules, Node (`cli/lib/apply.mjs`), `node:test`.

## Global Constraints (from the design spec §3, §7)

- `/goal` OWNS state init, transitions, the two gates, the single ship commit, ticking the
  ship-gate checklist, and the terminal transition. Subordinate skills under `owner=goal`
  contribute only their phase's work; they MUST NOT re-init `.workflow/state.md`, run
  `git commit`/push/PR, or self-cap a review loop.
- `commit_policy`: `per-task` (default, standalone) = the implementer commits per task and reports
  the commit sha. `defer` (used by `/goal`) = the implementer **stages only, does not commit**, and
  reports `task-id + test evidence + before/after tree digest`; the orchestrator makes the single
  commit at ship (so ship-gates' "no commit before green" holds).
- The generated agent must be **static but commit_policy-aware**: it honors whatever policy the
  dispatching driver states in the task brief (it is written once at install time and cannot know
  per-run whether a `/goal` loop is active).
- No linter regressions: `npm run check` (lint + evals + tests) stays green after each task.

---

## File Structure

- `src/shared/rules/execution.md` — add the `owner` + `commit_policy` contract (Task 1).
- `cli/lib/apply.mjs` — `applyClaudeAgents` emits a commit_policy-aware agent (Task 2).
- `tools/test/apply.test.mjs` — assert the agent honors `commit_policy`/`defer` (Task 2).
- `src/skills/{plan,review,new-feature,finish-branch}/SKILL.md` — `owner=goal` notes (Task 3).

---

### Task 1: `execution.md` — add the `owner` + `commit_policy` contract

**Files:** Modify `src/shared/rules/execution.md`.
**Interfaces:** Produces the normative definitions Task 2's agent text and Task 3's skill notes and
Plan C's `/goal` skill all reference.

- [ ] **Step 1: Append the contract section**

Add this section to `src/shared/rules/execution.md` (after the existing "How to apply it" section):

```markdown
## Orchestration: `owner` and `commit_policy`

A workflow skill normally runs **standalone** (`owner=self`): it initializes `.workflow/state.md`,
drives its own phases, and ships. An **orchestrator** skill (currently only `goal`) instead drives
the composed skills as subordinate phase-workers under `owner=goal`:

- **`owner=goal`** — the orchestrator OWNS state init, all phase transitions, the human gates, the
  single ship commit, and the terminal transition. A subordinate skill contributes only its phase's
  work and its named `.workflow/state.md` sections; under `owner=goal` it MUST NOT (a) copy the
  state template / re-init state, (b) run `git commit` / push / `gh pr create`, or (c) self-cap a
  review loop (the orchestrator owns the breaker). Default is `owner=self` — unchanged behavior.

- **`commit_policy`** — how the implementer of a plan task treats commits:
  - `per-task` (default, standalone): implement TDD, run the covering tests, **commit**, and report
    status + the commit sha + a one-line test summary.
  - `defer` (used by `owner=goal`): implement TDD, run the covering tests, **stage the task's files
    only — do NOT commit**, and report status + the task id + a one-line test summary + the
    before/after working-tree digest (`shared/scripts/goal-digest.sh`). The orchestrator makes the
    single commit at ship, once the gates are green — so `ship-gates.md`'s "no commit before all
    gates green" holds even in subagent-driven mode.

The dispatching driver states the `commit_policy` in each task brief; the implementer honors it.
```

- [ ] **Step 2: Verify the linter is green**

Run: `npm run check`
Expected: PASS. (`execution.md` is referenced by `new-feature`/`fix-bug`; the lint checks shared/
reference integrity and does not object to added prose.)

- [ ] **Step 3: Commit**

```bash
git add src/shared/rules/execution.md
git commit -m "docs(rules): execution.md owner + commit_policy contract for /goal orchestration"
```

---

### Task 2: `cli/lib/apply.mjs` — commit_policy-aware generated agent

**Files:** Modify `cli/lib/apply.mjs` (`applyClaudeAgents`); Test `tools/test/apply.test.mjs`.
**Interfaces:** `applyClaudeAgents(targetDir, answers)` unchanged signature; the emitted
`codeforge-implementer.md` now documents both commit policies.

- [ ] **Step 1: Write the failing test** (append to `tools/test/apply.test.mjs`)

```js
test('generated implementer agent is commit_policy-aware (per-task + defer)', () => {
  const dir = mkdtempSync(join(tmpdir(), 'cf-agents-cp-'));
  mkdirSync(join(dir, '.claude'), { recursive: true });
  applyClaudeAgents(dir, { claude: { subagents: true, model: { model: 'sonnet', effort: 'high' } } });
  const f = readFileSync(join(dir, '.claude', 'agents', 'codeforge-implementer.md'), 'utf8');
  assert.match(f, /commit_policy/);                 // documents the contract
  assert.match(f, /per-task/);                      // default: commit + sha
  assert.match(f, /defer/);                         // /goal: stage only, no commit
  assert.match(f, /stage[^\n]*only|do NOT commit/i);// the defer behavior is explicit
  assert.match(f, /^model: sonnet$/m);              // still model-parameterized
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `node --test tools/test/apply.test.mjs`
Expected: FAIL — the current agent body has no `commit_policy`/`defer`.

- [ ] **Step 3: Update the generated agent template** in `cli/lib/apply.mjs`

Replace the `const file = \`---\n...\`;` template in `applyClaudeAgents` (currently
`cli/lib/apply.mjs:88-98`) with:

```js
  const file = `---
name: codeforge-implementer
description: Implements exactly one task from the active codeforge plan (TDD: red → green → refactor), runs the covering tests, and reports back. Honors the dispatch brief's commit_policy (per-task = commit + report sha; defer = stage only, no commit, report tree digest). Dispatch one per task when running subagent-driven.
model: ${c.model.model}
---

You implement ONE task from the active codeforge plan. Read the task, write the failing
test first, make it pass with the minimal change, run the covering tests. Then honor the
**commit_policy** the dispatching driver gave you (see shared/rules/execution.md):

- commit_policy=per-task (default): commit, then report status (DONE / BLOCKED), the commit
  sha, and a one-line test summary.
- commit_policy=defer (used by /goal): do NOT commit — stage this task's files only, then
  report status (DONE / BLOCKED), the task id, a one-line test summary, and the before/after
  working-tree digest (shared/scripts/goal-digest.sh). The orchestrator commits at ship.

Do not start other tasks. Follow the repo's TDD and ship-gate rules.
`;
```

- [ ] **Step 4: Run to verify it passes**

Run: `node --test tools/test/apply.test.mjs`
Expected: PASS (the new assertion + the two existing `applyClaudeAgents` tests still green — the
`model: sonnet` and `name:` matches are preserved).

- [ ] **Step 5: Commit**

```bash
git add cli/lib/apply.mjs tools/test/apply.test.mjs
git commit -m "feat(cli): commit_policy-aware codeforge-implementer agent (per-task | defer)"
```

---

### Task 3: `owner=goal` notes in `plan` / `review` / `new-feature` / `finish-branch`

**Files:** Modify `src/skills/plan/SKILL.md`, `src/skills/review/SKILL.md`,
`src/skills/new-feature/SKILL.md`, `src/skills/finish-branch/SKILL.md`.
**Interfaces:** additive prose; no behavior change standalone.

The skill linter (`tools/lint-skills.mjs`) requires each skill keep its frontmatter, the
`## Common rationalizations` / `## Red flags` / `## Verification` anatomy, and CLAUDE.md index
parity. These edits only ADD a short note; they touch none of those, so lint stays green.

- [ ] **Step 1: Add the note to `plan/SKILL.md`**

After the "## 5. Hand off to implementation" section, add:

```markdown
## Under `/goal` (owner=goal)

When `/goal` drives this skill, `/goal` owns the plan-review loop and its `.workflow/state.md`
logging (`shared/rules/execution.md`). This skill still compares approaches and writes the plan,
but it does **not** run its own review loop to convergence or self-cap — it contributes one review
pass and its findings; `/goal` counts rounds and enforces the breaker.
```

- [ ] **Step 2: Add the note to `review/SKILL.md`**

After "## 4. Act and record", add:

```markdown
## Under `/goal` (owner=goal)

When `/goal` drives review, `/goal` owns the loop: it decides iterations, counts rounds, and
enforces the breaker (`shared/rules/execution.md`). This skill performs a single reviewer pass and
returns the severity-tagged findings; it does **not** loop to convergence itself under `owner=goal`.
```

- [ ] **Step 3: Add the note to `new-feature/SKILL.md`**

After "## 7. Ship", add:

```markdown
## Under `/goal` (owner=goal)

When `/goal` drives this workflow, `/goal` owns state init (§0) and shipping (§7) — this skill does
**not** copy the state template or run commit/push/PR under `owner=goal`. Implementers run with
`commit_policy=defer` (stage-only; `/goal` commits at ship). See `shared/rules/execution.md`.
```

- [ ] **Step 4: Add the note to `finish-branch/SKILL.md`**

After "## 6. Update transient state", add:

```markdown
## Under `/goal` (owner=goal)

When `/goal` orchestrates the finish, `/goal` performs the single ship commit and the GATE-2
authorization itself (`shared/rules/execution.md`). This skill's steps 4–5 (commit, push+PR) run
**under `/goal`'s control** — it does not independently commit/push; it confirms the gates and hands
the ship action to `/goal`'s explicit GATE-2 approval.
```

- [ ] **Step 5: Verify the linter is green**

Run: `npm run check`
Expected: PASS (anatomy + index parity intact; only additive notes).

- [ ] **Step 6: Commit**

```bash
git add src/skills/plan/SKILL.md src/skills/review/SKILL.md src/skills/new-feature/SKILL.md src/skills/finish-branch/SKILL.md
git commit -m "docs(skills): owner=goal notes (init/ship/loop-control belong to /goal)"
```

---

## Self-Review

**Spec coverage (Plan B scope):**
- §3 phase-ownership contract (owner=goal; subordinates don't re-init/ship/self-loop) → Task 1
  (execution.md) + Task 3 (the four skills). ✓
- §7 commit_policy=defer + generated agent updated → Task 1 (contract) + Task 2 (apply.mjs). ✓
- §9 landing items "execution.md commit_policy", "apply.mjs commit_policy-aware", "plan/review/
  new-feature/finish-branch owner=goal notes" → Tasks 1–3. ✓
- NOT in Plan B: the `/goal` skill itself, index, evals, template `## Blockers`/`## Attempts`,
  smoke — those are Plan C.

**Placeholder scan:** every step has the exact prose/code to add; no TBD.

**Consistency:** the `commit_policy` names (`per-task`/`defer`) and the `owner` values
(`self`/`goal`) are identical across execution.md (Task 1), the generated agent (Task 2), and the
four skill notes (Task 3). The agent's `defer` report shape (task-id + test evidence + before/after
tree digest via `goal-digest.sh`) matches execution.md's definition and Plan A's helper.

**Regression guard:** Tasks 1 and 3 are additive prose validated by `npm run check`; Task 2 keeps
the existing `applyClaudeAgents` tests green (model + name assertions preserved) and adds the
commit_policy assertion. No non-`/goal` behavior changes (defaults = today).
