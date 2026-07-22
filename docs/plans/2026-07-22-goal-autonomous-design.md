# codeforge `/goal` — autonomous mode (Fase 2) — design spec

**Written:** 2026-07-22. **Branch:** `feat/goal-autonomous` (off `dev`, v0.6.0).
**Status:** design approved in brainstorming; **revised twice** after cross-engine spec review
(iter 1 + iter 2, Opus + Codex `gpt-5.6-sol` + OpenCode `kimi-k3`) — see §14. Next: focused
re-review of §6/§4 → human spec-review gate → writing-plans.

Repo: `~/Desktop/personal/projects/forge-ai` (GitHub `Juan-Motta/codeforge`, npm
`@jualopezmo/codeforge`). Cross-engine (Claude Code / Codex / OpenCode) workflow-discipline
framework. `/goal` is the top remaining capability gap vs the origin `claude-codex-forge`; a
cross-engine `/goal` is **unique** (the origin's is Claude+Codex only).

---

## 1. Goal

A resumable, mostly-autonomous workflow driver that takes a **single feature objective** from
idea to a PR-ready branch — `prd → research → plan → review → TDD → review → simplify → verify →
PR` — pausing for the human at **exactly two** planned points (entry approval + PR creation) plus
any unplanned HALT.

Between the two gates it runs autonomously; genuinely ambiguous forks route to `council`;
non-convergence and unrecoverable failure HALT for a human. It must run **identically under
Claude Code, Codex, and OpenCode** — which requires a **capability preflight** (§6.4) before the
first gate that proves the loop's own autonomous actions (cross-engine reviewer/council spawns)
are prompt-free on the driver engine. If that cannot be proven, `/goal` does **not** enter the
autonomous middle — it HALTs honestly rather than silently stalling on a per-round prompt.

Honesty: the two-pause guarantee is delivered by an **explicit driver-issued approval step on
all three engines** (§5), never by an engine's bypassable native permission prompt. The autonomy
is skill-level discipline; the only bad-faith-resistant hard gate remains the fully-activated
Fase 1 CI template (§8).

### Scope decision (locked): **feature-only in v1**

v1 drives feature objectives only. A bug objective is **explicitly rejected** at classification
with a route to `/fix-bug` — never silently half-routed into the feature machine.

### Non-goals (YAGNI)

- No new hook/enforcement mechanism (`--with-hooks` retired in Fase 1, stays retired).
- No re-implementation of phase logic owned by existing skills.
- No dedicated third state file — loop state lives in `.workflow/state.md`.
- No auto-approval of `ask`-tier prompts.
- No bug path in v1.

---

## 2. Decisions locked in brainstorming + review

| # | Fork | Decision |
| - | ---- | -------- |
| 1 | Enforcement posture | **Discipline + `check-gates` at the SHIP transition only (Attested), cross-engine, honest.** Intermediate phase progress is **Advisory**. |
| 2 | Durable resume | **Reuse `.workflow/state.md` (`## /goal loop` + `## Blockers`) + `CONTINUITY.md`.** A **tested, mandatory** state helper owns the atomic writes (§9); it is not an enforcement hook. |
| 3 | Human pause points | **Entry (PRD approval) + PR creation only**, both explicit driver-issued approvals on all three engines. Ambiguous → `council`; non-convergence / unrecoverable failure → human HALT. |
| 4 | v1 scope | **Feature-only.** Bug objectives rejected → `/fix-bug`. |
| 5 | Autonomy precondition | **Capability preflight (§6.4) before GATE 1.** If reviewer/council spawns aren't prompt-free on the driver engine, or no non-driver reviewer exists, `/goal` HALTs before the autonomous middle — it never degrades to per-round prompting or driver self-review. |

### Chosen approach: **A — orchestrator that composes existing skills**

`/goal` is a thin engine-neutral `SKILL.md` the driver follows, composing existing skills as
subordinate phase-workers under an explicit ownership contract (§3) and advancing a state machine
(§4, §11). Rejected B (duplicate content → DRY/linter friction) and C (bare wrapper → no explicit
phase ledger, which decision #2 requires).

---

## 3. Architecture + composition contract

`/goal <objetivo>` → new file `src/skills/goal/SKILL.md`, engine-neutral.

```
/goal <objetivo>
  → classify: feature | bug
        bug  → STOP, tell the human to run /fix-bug  (v1 rejects bugs)
        feature ↓
  → CAPABILITY PREFLIGHT (§6.4): prove reviewer/council spawns are prompt-free on the
        driver engine AND a non-driver reviewer is available. If not → HALT (no autonomy).
  → prd            → GATE 1 (human, explicit, all engines): approve PRD ────────────────┐
  → research       (only if external tech)                                              │
  → plan           (its internal review IS the /goal plan-review pass; the plan skill    │
        must emit §10 review-log lines, honor breaker N, and return a certification flag)│ autonomous
  → tdd            (execution.md; implementers commit_policy=defer, non-committing — §7) │  ambiguous → council
  → code-review LOOP (bounded — §6):                                                     │  non-convergence → HALT
        review rounds → first clean pass → run simplify ONCE → one certification pass    │  unrecoverable fail → HALT
        at the post-simplify digest → exit                                              │
  → verify-e2e     (or honest N/A)  [if it changes code, certification is invalidated —  │
        §6.5, re-enter code-review]                                                      │
  → finish-branch  → GATE 2 (human, explicit, all engines): create PR ───────────────────┘
```

`simplify` is **not** a phase that flows to `verify`; it is a **sub-step inside the code-review
loop** (§6.3). The only exit from that loop is a certification pass at the current digest.

### Phase-ownership contract (mandatory in the skill body)

Composed skills were authored to run standalone: `new-feature §0` copies the state template and
**initializes `.workflow/state.md`**; `new-feature §7` / `finish-branch` **own shipping**
(verified `src/skills/new-feature/SKILL.md:14,56-60`). Composed naïvely they erase `/goal`'s loop
state or self-ship. The contract:

- **`/goal` OWNS:** one-time state initialization (incl. `## /goal loop` + `## Blockers`), all
  phase transitions, the `step` task cursor (§10), retries + durable attempt counters (§7), the
  two human gates, the single ship commit, and the terminal transition. `/goal` composes
  subordinate skills **in `owner=goal` mode**: they contribute only their phase's work + their
  named section(s) in `state.md`, and MUST NOT (a) re-initialize state, (b) run `git commit` /
  push / PR, or (c) self-cap a review loop silently.
- **`plan`** contributes the plan + its cross-engine design review, which **is** the `/goal`
  plan-review pass (no second, separate plan review). Under `owner=goal`, `plan`'s internal review
  MUST emit §10 review-log lines per round, honor the breaker budget N (§6.2), and **return a
  certification flag**; an uncertified return is treated by `/goal` as a breaker HALT.
- **`new-feature` / `finish-branch`** are composed for their phase content only; their standalone
  init (`§0`) and ship (`§7`) steps are disabled under `owner=goal` (see §9 — `execution.md` +
  the generated agent gain an `owner`/`commit_policy` contract). `/goal` performs init and ship.
- On Claude Code, implementers run via the `codeforge-implementer` subagent (§7) with
  `commit_policy=defer`.

---

## 4. State machine — `## /goal loop` + `## Blockers` in `.workflow/state.md`

`## /goal loop` is the **single authoritative** loop state (REPLACE semantics — §4.1). It does
NOT duplicate the existing `## Active workflow` `Phase`; `/goal` supersedes that field for the
loop's duration and `## /goal loop.phase` is the source of truth.

```
## /goal loop

| Field     | Value                                                                     |
| --------- | ------------------------------------------------------------------------- |
| nonce     | <uuid-v4-lowercase>   (empty ⇒ INACTIVE / terminal)                       |
| goal      | <one-line feature objective>                                              |
| status    | active | awaiting-gate1 | awaiting-gate2 | halted | done                  |
| phase     | preflight|prd|research|plan|tdd|code-review|verify|ship                   |
| step      | <phase>:<N>/<M>  (e.g. tdd:16/20; the task cursor /goal OWNS — §10)        |
| base_sha  | <merge-base SHA at kickoff; the digest base — §10>                        |
| gate1     | <see §10 gate1 record; empty until approved>                              |
| issued_at | <ISO-8601-UTC>                                                            |
```

GATE 2 authorization, review rounds, blockers, and attempt counters are recorded as **fixed-schema
lines** (§10) in `## /goal loop` (for GATE 2 auth), `## Review log`, and `## Blockers`
respectively — parseable by the state helper.

### 4.1 Kickoff, REPLACE, and collision (fix N10)

Kickoff writes `## /goal loop` with REPLACE semantics (whole section overwritten atomically). But
kickoff **MUST REFUSE** when `nonce` is non-empty (an active/halted loop exists): it stops and
requires the human to either (a) write an explicit abandon line in `## Blockers`
(`- [x] ABANDON loop nonce=<n> — <disposition of staged tree> — ts=<ts>`) **and** clean/disposition
the working tree, or (b) resume the existing loop. Never silently REPLACE a live loop — that would
erase a HALT record and fold orphaned staged changes into a new loop's ship commit.

### 4.2 Resume procedure (fix N-cursor, N6, P2 gate1-guard)

On a new session or after compaction, read `.workflow/state.md` **with the Read tool** (never
Bash) + `CONTINUITY.md`, then apply this numbered procedure (this is the part §9 tests):

1. If `nonce` empty OR `status=done` → **INACTIVE**; do not resume.
2. If `status=halted` OR any **unresolved** `## Blockers` line exists (§10) → **STOP, report to
   the human**; resume only after a human head-bound adjudication line resolves every blocker.
3. If `status=awaiting-gate1` OR `gate1` empty → re-issue GATE 1 (never auto-enter the autonomous
   middle without a valid `gate1` record).
4. If `status=awaiting-gate2` → re-issue GATE 2 (§5).
5. Else `status=active` → continue from `phase`+`step`, never restarting a completed phase;
   intra-phase, continue from the `step` cursor.

### 4.3 Terminal

On successful PR creation, set `status=done` **and** clear `nonce`. Empty `nonce` is the sole
terminal signal; a resuming driver treats `nonce`-empty (or `status=done`) as INACTIVE (§4.2.1).

---

## 5. Human gates (portable + content/action-bound — fixes P0-B, N9)

### GATE 1 — entry (PRD approval)
After `prd`, set `status=awaiting-gate1` and issue an **explicit approval request** (`AskUserQuestion`
on Claude; a plain in-conversation prompt on Codex/OpenCode). On approval, write the **gate1
record** (§10: `approved ts + prd path + prd_digest`) and set `status=active`. The autonomous run
does not begin until a valid `gate1` record exists. Any later change to the PRD (digest mismatch)
invalidates `gate1` and re-issues GATE 1.

### GATE 2 — PR creation (portable)
`finish-branch` reaches push / `gh pr create`. Before running **any** push or PR command, on all
three engines the driver issues an **explicit in-conversation approval** (`AskUserQuestion` on
Claude; plain prompt elsewhere). The engine's native `ask`-tier prompt is **defense-in-depth
only** (bypassable / may be absent under an allow-list or full-auto). Only after explicit approval
does the driver write the **gate2 authorization line** (§10: `nonce + action set + HEAD + tree
digest + branch + remote + ts`). The driver **re-verifies HEAD and tree digest against that line
immediately before EACH push AND each PR action** (not only before `gh pr create`), including on
resume; any mismatch clears the authorization, sets `status=awaiting-gate2`, and re-issues GATE 2.

Council routing and NON-triggers are unchanged from the prior revision: ambiguous fork → `council`;
normal review iterations and non-convergence are NON-triggers (non-convergence → human HALT); if
`council` itself fails → HALT + `## Blockers` + `status=halted`.

---

## 6. Cross-engine review loops + bounded convergence

Two loops: **plan-review** (the `plan` skill's own cross-engine review, run under `owner=goal` per
§3) and **code-review** (post-TDD, reviewer(s) + a self-pass over the diff). Reviewer ≠ driver
(`models.md`).

### 6.1 The certification digest (fix N1 — the load-bearing definition)

Each review pass is bound to a **canonical content digest**, not HEAD (an uncommitted plan/diff
shares one HEAD across edits; implementers stage-only per §7 so `git diff` alone can be empty).
The digest is computed **at pass start, before the round's review-log line is appended**, as:

> `sha256` over the concatenation of (a) `git diff <base_sha>` covering **tracked staged +
> unstaged** changes, and (b) the sorted contents of **untracked, non-git-ignored code files**,
> **EXCLUDING** everything under `.workflow/`, `docs/e2e/reports/`, `CONTINUITY.md`, and any other
> state/evidence/review-log artifact.

The exclusion is mandatory: without it, appending the mandatory review-log line (or any state
write) would change the digest and **no pass could ever certify** (the loop would always HALT at
N). `base_sha` is recorded at kickoff (§4). The exact byte-level command is finalized in the plan
(§12) but the definition above is normative.

### 6.2 Bounded termination (fixes P0-A + N2 plan-loop)

- **Certification = the single exit condition:** the first pass where all *expected* reviewers are
  clean (no P0/P1/P2) **at the same digest**. Each round appends a §10 review-log line.
- **Breaker:** rounds are counted **from loop start**, per loop. If a loop has **not certified
  within N rounds** (default `N=4`, a named constant), the driver **HALTs** (`## Blockers`,
  `status=halted`). This bounds the genuinely non-converging case that never reaches an all-clean
  pass. Rounds that consist only of the simplify+re-certify sequence (§6.3) do **not** consume N.
- **Plan-review loop:** because `plan` runs its review internally, the §3 contract requires it to
  emit §10 review-log lines per round, honor N, and **return a certification flag**. `/goal` treats
  an uncertified return (or N exceeded) as a breaker HALT — the breaker reaches the plan loop, not
  just the code loop.
- **Release:** human-only, via a §10 adjudication line that **explicitly carries a budget effect**
  (`rounds-reset` or `budget+K`); only post-adjudication rounds count thereafter (fix N6 — without
  this, resume recomputes N uncertified rounds and instantly re-HALTs = deadlock). The driver never
  writes the adjudication line.

### 6.3 `simplify` placement (fix N3)

`simplify` runs **exactly once**, immediately after the **first clean pass**, inside the
code-review loop. Exactly **one** certification pass follows, at the **post-simplify digest**. The
simplify + re-certify sequence does not consume N (§6.2). The loop exits only when
`digest-at-exit == digest-at-certification` (nothing changed after the certifying pass). Rationale
is **digest binding** (reviewers must certify the final content), not "no commit between cert and
exit" (moot — §7 removed all mid-loop commits). This is a `/goal`-scoped override of
`new-feature §5`'s standalone "clean review THEN simplify" ordering; `/goal` owns the transition.

### 6.4 Capability preflight (fix N7, N8 — runs BEFORE GATE 1)

Before entering the autonomous middle, `/goal` proves, on the **driver engine**:

1. A **non-driver reviewer** engine is available (`models.md`); if the configured default reviewer
   equals the driver, a different available engine is selected.
2. Spawning that reviewer/council CLI (`claude -p` / `codex exec` / `opencode run`) is
   **prompt-free** under the driver engine's current permission config.

If either fails → **HALT before GATE 1** with a `## Blockers` line explaining the missing
capability (e.g., "reviewer spawn would prompt; add the allow-entry and re-run"). `/goal` does
**not**: degrade to per-round prompting (breaks the two-pause + cross-engine claims), or invoke the
`ship-gates.md` single-engine **delayed-self-review** waiver in autonomous mode (that waiver's
human-review branch is unavailable autonomously, and self-review would hollow out certification).
The delayed-self-review waiver remains valid for **interactive** (non-`/goal`) use only. The
required allow-entries for `.claude/settings.json` / `.codex/config.toml` / `opencode.json` are
documented for **all three** engines (the shipped `src/configs/claude/settings.json` has no Bash
allow-list today, so Claude needs entries too — this is not a Claude-only-is-free situation);
exact syntax is finalized in the plan's research step (§12).

### 6.5 Certification does not survive content change (fix N5)

Certification is bound to a digest. **Any working-tree change after certification invalidates it.**
Concretely: if `verify-e2e` (or a §8 red-path fix) changes code, the driver MUST re-enter the
code-review loop before shipping — it may not carry a stale "Code review clean" box to the ship
transition. Dependency invalidation: a plan change clears all downstream evidence (code-review +
verify + gate2 auth); a code change clears code-review + verify + gate2 auth; a verify change
invalidates the final snapshot. The ship transition (§8) re-checks `ship-tree digest ==
certification digest` and refuses if they differ.

---

## 7. Per-engine execution + failure handling

- **Execution mode** per `execution.md`: subagent-driven on Claude Code, inline on Codex/OpenCode.
- **`commit_policy=defer` (fixes P1-E + N4).** `execution.md` and the generated
  `codeforge-implementer` agent gain an explicit `commit_policy` contract with values
  `per-task` (today's default, standalone use) and `defer` (`/goal` use). Under `defer`, the
  implementer **stages only after its task is green and accepted**, does **not** commit, and
  reports `task-id + test evidence + before/after tree digest` instead of a commit SHA. `/goal`
  then writes the durable task cursor `step=<phase>:<N>/<M>` into `## /goal loop`. `/goal` makes
  the single commit at the ship transition once gates are green. Inline mode likewise defers.
  The generator (`cli/lib/apply.mjs`, verified to currently order "commits… report the commit
  sha") is updated to emit the `commit_policy`-aware agent (§9).
- **Durable attempt counters (fix N11).** "retry once" / "twice-red → HALT" counters are persisted
  as §10 attempt lines keyed by `operation/transition + failure fingerprint`, incremented
  **before** each attempt, so a restart between failures cannot reset the budget.
- **Tool/subagent failure:** retry once (per the durable counter) → if still failing and recovery
  is a judgment call → `council`; else HALT (`## Blockers`, `status=halted`).
- **`ask`-tier commands (`rm -rf`, etc.):** an autonomous loop cannot self-approve the native
  prompt. Any **unavoidable** ask-tier action MUST **HALT explicitly** (write `## Blockers`,
  `status=halted`) and hand to the human — it must NOT launch a command that then blocks silently
  (announcing it is not enough; the native prompt still hangs the run). Prefer prompt-free
  alternatives (cache flags, `: >` truncation instead of `rm`).

---

## 8. Enforcement model (honest — fixes P1-G, N5 red path)

- **`check-gates.sh` is a terminal, full-profile validator, not a per-phase checkpoint** (verified:
  validates the entire standard profile by identity + count, requires `Code review clean` /
  `E2E verified` / `State updated`, so it can only pass at ship). The driver runs it **only before
  shipping**. Intermediate phase progress (`## /goal loop` `phase`/`status`) is **Advisory**.
- **Ship-gate red path:** if `check-gates` is red at ship, the driver returns to the **owning
  phase** to green it. If the greening fix **touches code**, it MUST re-enter the code-review loop
  (§6.5) — never jump straight back to ship carrying a stale certification. If the **same
  transition** fails twice (per the durable counter, §7), HALT (`## Blockers`, `status=halted`).
  The ship transition additionally refuses unless `ship-tree digest == certification digest`.
- **CI honesty:** reuse the exact conditional wording from `ship-gates.md` — the Fase 1 CI template
  is **inert until copied into `.github/workflows/`, its test step filled, and made a required
  status check**, and becomes bad-faith-**resistant** only with full activation (CODEOWNERS on the
  workflow + test-defining files, dismiss-stale-approvals, strict/up-to-date checks or a merge
  queue, bypass disabled for admins). Never called "the hard gate" unconditionally.

Honesty block (in the skill body): *"This autonomy is discipline plus a terminal Attested
checkpoint, not a runtime hard gate. Intermediate progress is Advisory. On all three engines the
only bad-faith-resistant gate is the fully-activated Fase 1 CI template. `/goal` does not, and
cannot, block a bad ship locally."*

---

## 9. Landing checklist (linter / evals / tests / generator)

- `src/skills/goal/SKILL.md` — full anti-rationalization anatomy (`## Common rationalizations` +
  `## Red flags` + `## Verification`, HARD-required by `tools/lint-skills.mjs`). Body carries the
  §3 ownership contract, §5 portable gates, §6 convergence + preflight, §7 `commit_policy=defer`,
  §8 honesty block.
- `src/CLAUDE.md` — add `goal` to the "Workflow skills" index (parity is a linter hard error).
- `tools/run-evals.mjs` — routing/collision cases for `/goal` (rank-1 ≥ floor); no collision with
  `new-feature`/`fix-bug`; a **bug-objective → route to /fix-bug** rejection case.
- `src/shared/state.template.md` — add `## /goal loop` (INACTIVE default) **and `## Blockers`**.
- `src/shared/rules/execution.md` — add the `owner` + `commit_policy=per-task|defer` contract.
- `cli/lib/apply.mjs` — update the generated `codeforge-implementer` agent to be
  `commit_policy`-aware (report task-id + test evidence + before/after tree digest under `defer`,
  not a commit SHA). Update the wizard/tests that assert the agent body.
- `src/shared/rules/workflow.md` — add a `/goal` row + a short "autonomous run" note.
- Tests (`tools/test/*.test.mjs`, `node --test`, zero-dep): the **mandatory** state helper —
  `## /goal loop` REPLACE + collision refusal (§4.1), the §4.2 resume decision (inactive / halted /
  awaiting-gate1 / awaiting-gate2 / active), the §10 line parsers (review-log, gate1, gate2,
  blocker, attempt, cursor), digest exclusion set (§6.1), and the §11 transition table invariants.
  Assert the skill passes the linter + routes rank-1 + bug objectives are rejected. Extend
  `tests/smoke.sh` expected-skills to include `goal`.
- `docs/CHANGELOG.md` — under `## Unreleased`; stays on v0.6.0 (no release cut now, per user).

---

## 10. Data schemas (normative — the operational contract)

All lines are single-line, fixed-order, parseable by the state helper. `<sha>`=git SHA,
`<digest>`=§6.1 content digest, `<ts>`=ISO-8601-UTC.

- **Task cursor** (`## /goal loop.step`): `<phase>:<N>/<M>` — N tasks done of M. `/goal` writes it
  after each staged+accepted task.
- **gate1 record** (`## /goal loop.gate1`): `approved ts=<ts> prd=<path> prd_digest=<sha256>`.
  Empty until approved. Digest mismatch ⇒ re-gate.
- **gate2 authorization** (line in `## /goal loop`): `- [x] GATE2 authorized — nonce=<n> —
  action=push+pr — head=<sha> — tree_digest=<digest> — branch=<b> — remote=<r> — ts=<ts>`.
  Re-verified before each push and each PR action; mismatch clears it.
- **Review-log line** (`## Review log`): `- <plan|code>-review round <N> — <reviewer-engine> —
  <clean | findings P0=a/P1=b/P2=c> — digest=<digest> — base=<sha> — ts=<ts>`. Certification =
  first N where all expected reviewers are `clean` at one `digest`.
- **Blocker line** (`## Blockers`), unresolved: `- [ ] BLOCKER <id> — <phase> — <reason> —
  tree_digest=<digest> — ts=<ts>`. Resolved (human, head-bound):
  `- [x] BLOCKER <id> — ADJUDICATED — <decision> — budget=<rounds-reset | +K> — head=<sha> —
  ts=<ts>`. Resume rule §4.2.2 treats any `- [ ] BLOCKER` as unresolved.
- **Attempt counter** (`## Blockers` or a dedicated `## Attempts` block): `- ATTEMPT
  <operation-or-transition> — fingerprint=<hash> — n=<k> — ts=<ts>`, incremented before each try.
- **Abandon line** (`## Blockers`): `- [x] ABANDON loop nonce=<n> — <staged-tree disposition> —
  ts=<ts>` (required by §4.1 before a new loop replaces a live one).

---

## 11. State transition table (normative)

| From `phase`/`status` | Event | To | Writes |
| --- | --- | --- | --- |
| — / (no loop) | `/goal <feature>` + preflight OK | `preflight`→`prd` / `awaiting-gate1` | init `## /goal loop` (refuse if nonce set — §4.1), `base_sha` |
| — / — | `/goal <bug>` | (none) | STOP → route to `/fix-bug` |
| `preflight` | reviewer spawn prompts / no non-driver reviewer | `halted` | `## Blockers` (§6.4) |
| `prd` / `awaiting-gate1` | human approves | `research`\|`plan` / `active` | `gate1` record |
| `plan` / `active` | plan returns certified | `tdd` | review-log lines |
| `plan` / `active` | plan uncertified OR N exceeded | `halted` | `## Blockers` |
| `tdd` / `active` | task k green+accepted | `tdd` | `step=tdd:k/M` (stage only, no commit) |
| `tdd` / `active` | all tasks done | `code-review` | — |
| `code-review` / `active` | first clean pass | `code-review` (simplify sub-step) | review-log line |
| `code-review` / `active` | post-simplify re-certify clean, digest stable | `verify` | review-log line |
| `code-review` / `active` | N exceeded uncertified | `halted` | `## Blockers` |
| `verify` / `active` | verify changes code | `code-review` | invalidate certification (§6.5) |
| `verify` / `active` | verify pass / N/A | `ship` / `awaiting-gate2` | evidence |
| `ship` / `awaiting-gate2` | human approves | `ship` / `active` | `gate2` auth line |
| `ship` / `active` | check-gates red, fix touches code | `code-review` | invalidate cert |
| `ship` / `active` | check-gates green, digest matches, PR created | `done` (nonce cleared) | — |
| any / `active` | unrecoverable failure / ask-tier unavoidable / council fails | `halted` | `## Blockers` + attempt line |
| `halted` | human adjudication line (budget effect) | resume owning phase | resolve blocker |

---

## 12. Open questions for the plan (v1-blocking ones resolved in-spec)

- Exact byte-level digest command implementing §6.1 (exclusion globs, untracked-file ordering,
  normalization) — finalize + test in the plan.
- Exact reviewer/council pre-allow syntax for `.claude/settings.json` / `.codex/config.toml` /
  `opencode.json` (§6.4) — verify against current schemas in the plan's research step.
- `N` default (4) — tune against real runs; named constant.
- State helper home: `shared/scripts/` (ships to targets — `/goal` runs in targets) with tests in
  `tools/test/`. Confirm in the plan.

---

## 13. How this proceeds (process)

1. **Focused re-review of §6/§4** (the hot zones) — Opus + Codex `gpt-5.6-sol` + OpenCode `kimi-k3`.
2. Human spec-review gate → adjust inline.
3. `superpowers:writing-plans` → implementation plan (task list + test stubs, incl. the §10 schemas
   and §11 table as testable units).
4. **Cross-engine plan review** (mandatory).
5. `superpowers:subagent-driven-development` — per-task impl + review; final whole-branch review
   (Opus + Codex) before PR.
6. PR `feat/goal-autonomous` → `dev`. Stays on v0.6.0 (no release cut now, per user).

---

## 14. Spec review log

- **Iteration 1 — 3 engines — 2026-07-22.** Found 2 P0 + 8 P1 + 2 P2; all resolved in revision 1.
  (Convergence-breaker dead code, GATE 2 bypassable, composition/resume/commit/reviewer-spawn/
  check-gates/bug-path/CI-honesty/routing.)
- **Iteration 2 (focused §3–§8) — 3 engines — 2026-07-22.** Confirmed 7–8 iter-1 findings CLOSED
  (P0-B, P1-C, P1-E, P1-F, P1-G, P1-I, P1-J, P2-K). Found the revision **not clean**: 11
  consolidated new P1s (3 P0-class under plausible readings), all in §6/§4. Resolved in **this**
  revision (revision 2):
  - **N1** digest undefined → §6.1 normative digest with mandatory `.workflow/**` + evidence
    exclusion, computed before the log append.
  - **N2** plan-review loop had no breaker → §3/§6.2 contract: `plan` emits review-log lines, honors
    N, returns a certification flag; uncertified ⇒ HALT.
  - **N3** simplify placement → §6.3 exactly-once, one post-simplify re-cert, doesn't consume N,
    digest-at-exit == cert digest; §3 diagram fixed; overrides `new-feature §5`.
  - **N4** resume cursor lost + generated agent commits → §7 `commit_policy=defer` + `/goal`-owned
    `step` cursor (§10); §9 updates `execution.md` + `cli/lib/apply.mjs` (verified it orders a
    commit today).
  - **N5** cross-phase certification laundering → §6.5 + §8: any post-cert code change invalidates
    certification; red-path code fix re-enters code-review; ship refuses on digest mismatch.
  - **N6** breaker-release deadlock → §6.2 adjudication line carries an explicit budget effect;
    only post-adjudication rounds count.
  - **N7** single-engine self-review contradiction → §6.4 HALT before autonomy; no self-review
    waiver in autonomous mode.
  - **N8** "Claude-only autonomy" false premise → §6.4 capability preflight for all three engines
    (verified shipped `src/configs/claude/settings.json` has no Bash allow-list).
  - **N9** gate records not content/action-bound → §5/§10 gate1 binds PRD digest; gate2 binds
    action+HEAD+tree digest+branch+remote; re-verify before each push and PR.
  - **N10** kickoff REPLACE collision → §4.1 refuse when nonce set; require human abandon +
    tree disposition.
  - **N11** non-durable failure counters + ask-tier hang → §7 persisted attempt lines (§10);
    unavoidable ask-tier HALTs explicitly instead of launching a blocking command.
  - P2 residuals folded in: `status=done` terminal value (§4), resume gate1-empty guard (§4.2.3),
    HALT-time staged-tree digest (§10 blocker line `tree_digest`).

  Raw reviewer outputs archived in the session scratchpad (not committed).
