# codeforge `/goal` — autonomous mode (Fase 2) — design spec

**Written:** 2026-07-22. **Branch:** `feat/goal-autonomous` (off `dev`, v0.6.0).
**Status:** design approved in brainstorming; **revised after 3-engine spec review** (Opus +
Codex `gpt-5.6-sol` + OpenCode `kimi-k3`) — see §12. Next: human spec-review gate → writing-plans.

Repo: `~/Desktop/personal/projects/forge-ai` (GitHub `Juan-Motta/codeforge`, npm
`@jualopezmo/codeforge`). Cross-engine (Claude Code / Codex / OpenCode) workflow-discipline
framework. This spec designs the `/goal` autonomous skill — the top remaining capability gap
vs the origin project `claude-codex-forge`. Cross-engine `/goal` makes codeforge's version
**unique** (the origin's is Claude+Codex only).

---

## 1. Goal

Add a resumable, mostly-autonomous workflow driver that takes a **single feature objective**
from idea to a PR-ready branch — `prd → research → plan → review → TDD → review → simplify →
verify → PR` — pausing for the human at **exactly two** planned points (entry approval + PR
creation) plus any unplanned HALT. Everything in between runs autonomously; genuinely ambiguous
forks route to the `council` skill instead of pausing; non-convergence and unrecoverable failure
HALT for a human.

It must run **identically under Claude Code, Codex, and OpenCode**, and it must be **honest**:
the two-pause guarantee is delivered by an **explicit driver-issued approval step on all three
engines** (§5), not by any engine's native permission prompt. The autonomy is skill-level
discipline; the only bad-faith-resistant hard gate remains the Fase 1 CI template **once fully
activated** (§8).

### Scope decision (locked): **feature-only in v1**

v1 drives feature objectives only (the `new-feature` phase sequence with a full PRD entry gate).
The bug path (`fix-bug`) is a deliberate **follow-up** with its own state/gate map. Consequently,
**objective classification must explicitly reject a bug objective** and route the human to
`/fix-bug` — it must NOT silently half-route a bug into the feature machine (review finding H).

### Non-goals (YAGNI)

- No new hook/enforcement mechanism. `--with-hooks` was retired in Fase 1 and stays retired.
- No re-implementation of phase logic already owned by existing skills.
- No dedicated third state file — loop state lives in the existing `.workflow/state.md`.
- No auto-approval of `ask`-tier prompts (an autonomous loop cannot, by design).
- No bug path in v1 (see scope decision above).

---

## 2. Decisions locked in brainstorming + review

| # | Fork | Decision |
| - | ---- | -------- |
| 1 | Enforcement posture of the loop's safety gates | **Discipline + `check-gates` at the ship transition (Attested), cross-engine, honest.** No new hooks. Intermediate phase progress is **Advisory** (the `## /goal loop` `phase`/`status` fields), not Attested — corrected per review finding G. |
| 2 | Durable resume of loop progress | **Reuse `.workflow/state.md` (new `## /goal loop` section) + `CONTINUITY.md`.** No new files. A tested, non-enforcing state-update helper is in scope (§4). |
| 3 | Human pause points | **Entry (PRD approval) + PR creation only**, both explicit driver-issued approvals on all three engines. Ambiguous → `council`; non-convergence / unrecoverable failure → human HALT. |
| 4 | v1 scope | **Feature-only.** Bug objectives are rejected with a route to `/fix-bug`. |

### Chosen approach: **A — orchestrator that composes existing skills**

`/goal` is a thin engine-neutral `SKILL.md` the driver follows. It does not duplicate skill
content (rejected B — DRY violation + linter index-parity friction) and it keeps an explicit
phase state machine (rejected C — a bare wrapper has no explicit phase ledger; decision #2
requires one). Composition requires an explicit **phase-ownership contract** (§3) because the
composed skills were written to run standalone (they re-init state and self-ship).

---

## 3. Architecture + composition contract

`/goal <objetivo>` → new file `src/skills/goal/SKILL.md`, engine-neutral. The driver follows it,
calling existing skills **as subordinate phase-workers** and advancing the phase machine in
`.workflow/state.md`.

```
/goal <objetivo>
  → classify: feature | bug
        bug  → STOP, tell the human to run /fix-bug (v1 rejects bugs)
        feature ↓
  → prd            → GATE 1 (human, explicit, all engines): approve PRD ──┐
  → research       (only if external tech)                                │
  → plan  (its internal review IS the /goal plan-review pass)             │ autonomous
  → plan-review loop (cross-engine, bounded — §6)                         │  ambiguous fork → council
  → tdd            (execution.md; implementers NON-committing — §7)       │  non-convergence → HALT
  → code-review loop (cross-engine, bounded — §6)                         │  unrecoverable fail → HALT
  → simplify       (runs INSIDE/at the tail of the code-review loop,      │
                    before certification, so no commit lands between      │
                    certification and loop exit — §6)                     │
  → verify-e2e     (or honest N/A)                                        │
  → finish-branch  → GATE 2 (human, explicit, all engines): create PR ────┘
```

### Phase-ownership contract (review finding C — mandatory in the skill body)

The composed skills (`prd`, `research`, `plan`, `new-feature`/its phases, `review`, `simplify`,
`verify-e2e`, `finish-branch`) were authored to run standalone: `new-feature §0` **copies the
state template and initializes `.workflow/state.md`**, and `new-feature §7` / `finish-branch`
**own shipping**. Composed naïvely, they would erase `/goal`'s loop state or ship on their own.
The skill therefore declares:

- **`/goal` OWNS:** one-time initialization of `.workflow/state.md` (including `## /goal loop`),
  all phase transitions, retries, the two human gates, and the terminal ship. Subordinate skills
  **must not** re-initialize state or trigger `git commit`/push/PR themselves.
- **Subordinate skills CONTRIBUTE** only their phase's work and their named section(s) in
  `state.md` (e.g., `plan` writes the plan + its `## Review log` design-review lines). `plan`'s
  built-in cross-engine review **is** the `/goal` plan-review pass — `/goal` does not run a
  second, separate plan review.
- **On Claude Code**, `/goal` runs implementers via the `codeforge-implementer` subagent
  (`execution.md`), but those implementers are **non-committing** (§7).

---

## 4. State machine — `## /goal loop` in `.workflow/state.md`

New section, **REPLACE semantics** (whole section overwritten atomically on each kickoff; a stale
loop is never appended to). It is the **single authoritative** loop state — it does **not**
duplicate the existing `## Active workflow` `Phase` field; `/goal` supersedes that field for the
duration of the loop and `## /goal loop.phase` is the source of truth (review finding D).

```
## /goal loop

| Field         | Value                                                              |
| ------------- | ------------------------------------------------------------------ |
| nonce         | <uuid-v4-lowercase>  (empty ⇒ INACTIVE)                            |
| goal          | <one-line feature objective>                                       |
| status        | active | awaiting-gate1 | awaiting-gate2 | halted                  |
| phase         | prd|research|plan|plan-review|tdd|code-review|simplify|verify|ship |
| step          | <cursor within phase, delegated to the composed skill's ledger>    |
| gate1         | <ISO-8601-UTC when approved, else empty>                           |
| issued_at     | <ISO-8601-UTC>                                                     |
```

- **Active** = `nonce` non-empty. `status` distinguishes running vs waiting-for-human vs halted.
- **`step`**: intra-phase progress (e.g., mid-TDD task 17/20) is delegated to the composed skill's
  own progress ledger (on Claude, the subagent-driven ledger). "Never restart a completed phase"
  must NOT be read as "restart the current phase from scratch" — resume continues from `step`
  within the current phase.
- **GATE 1 record**: the `gate1` timestamp is the durable proof the entry gate was approved
  (review finding: GATE 1 had no durable record). Resume must not enter the autonomous middle if
  `status=awaiting-gate1` or `gate1` is empty.
- **GATE 2 / PR authorization**: recorded per the existing gate convention — an authorization
  line carrying `nonce + HEAD SHA + branch/remote`, written **only after** the explicit GATE 2
  approval (§5), and re-verified against HEAD immediately before `gh pr create`.
- **Review-iteration counters** live in `## Review log` with a fixed schema so a resuming driver
  can recompute convergence deterministically (§6).
- **`## Blockers`**: every HALT path (non-convergence, council failure, tool failure, twice-red
  gate) writes a head-bound line here and sets `status=halted`. This section is **added to the
  state template** (it does not exist today) — review finding D.
- **Resume procedure** (review findings D/J): read `.workflow/state.md` **with the Read tool**
  (never Bash) + `CONTINUITY.md`. Then:
  1. If `status=halted` OR any unresolved `## Blockers` line exists → **STOP and report to the
     human**; resume only after the human writes a head-bound adjudication line clearing it.
  2. If `status=awaiting-gate1`/`awaiting-gate2` → re-issue that gate (do not auto-proceed).
  3. Else continue from `phase`+`step`, never restarting a completed phase.
- **Terminal**: on successful PR creation, `status` is set terminal and the `nonce` cleared so a
  later session does not treat the finished loop as active.
- **State-update helper**: a small, **tested, non-enforcing** helper (Node, zero-dep, in `tools/`
  or a shared script) may own the REPLACE-write of `## /goal loop` and the `## Review log`
  line-append, to make write-before/write-after semantics testable. It is **not** an enforcement
  hook — it only reads/writes state deterministically.

---

## 5. Human gates + council routing

### GATE 1 — entry (PRD approval)
After `prd`, the driver sets `status=awaiting-gate1` and issues an **explicit approval request**:
`AskUserQuestion` on Claude Code, a plain in-conversation approval prompt on Codex/OpenCode. On
approval it writes the `gate1` timestamp and sets `status=active`. The autonomous run does not
begin until `gate1` is set.

### GATE 2 — PR creation (portable; review findings B/P0-B)
`finish-branch` reaches `git push` / `gh pr create`. Before running ANY push/PR command, on
**all three engines** the driver issues an **explicit in-conversation approval request**
(`AskUserQuestion` on Claude; a plain approval prompt on Codex/OpenCode). The engine's native
`ask`-tier permission prompt is treated as **defense-in-depth only** — it is best-effort and may
be silently absent if the user has allow-listed `git push`/`gh` or runs full-auto, so it can
never be the gate. Only after explicit approval does the driver write the PR authorization line
(`nonce + HEAD + branch/remote`) and then re-verify HEAD against that line immediately before
`gh pr create` (including on resume).

### Council instead of pausing (autonomous middle)
The driver invokes `council` — not the human — when: an ambiguous product/technical choice would
otherwise prompt the user; a reviewer recommends **revising the plan** (not merely patching);
a high-impact implementation fork has multiple defensible approaches; a retried tool/subagent has
**also** failed and recovery is a judgment call; reviewer/council output is unrecognizable.

### Explicit NON-triggers
Normal plan-review / code-review loop iterations; **non-convergence** (→ human HALT, never
council). If `council` itself fails → **HALT**, write `## Blockers`, `status=halted`.

---

## 6. Cross-engine review loops + bounded convergence (review findings A/P0-A, K)

Reuse the `review` skill (reviewer ≠ driver; models per `models.md`). Two loops: **plan-review**
(the `plan` skill's own cross-engine review) and **code-review** (post-TDD, reviewer(s) + a
self-pass over the diff). Each loop exits **only** when no reviewer reports P0/P1/P2 on the same
pass — that clean pass is **certification, and certification is the single exit condition**
(there are not two definitions).

### Bounded termination (the fix for the dead-code breaker)
The breaker counts **rounds from loop start**, per loop, independent of certification:

- Each round appends to `## Review log` a fixed-schema line:
  `- <loop> iter <N> — <reviewer> — clean|findings=<P0/P1/P2 counts> — head=<sha> — digest=<sha256 of plan-or-diff>`
- **Breaker:** if a loop has **not certified within `N` rounds** (default `N=4`), the driver
  **HALTs for a human** with a `## Blockers` line and `status=halted`. This bounds the genuinely
  non-converging case that never reaches an all-clean pass — the case the origin's certification-
  relative counter silently missed.
- **Content binding:** each pass binds to a **content/diff `digest`**, not merely HEAD, because
  an uncommitted plan or working-tree diff shares one HEAD across edits. Certification is defined
  at a specific `digest`; a later change (new digest) is a new round.
- **`simplify` placement:** `simplify` runs **inside the code-review loop, before certification**,
  so no commit lands between certification and loop exit (removing the "post-clean commit leaves
  certification undefined" ambiguity). `simplify` therefore does not appear as a post-certification
  phase; the `simplify` enum value marks the sub-step for resume granularity only.
- **Release:** human-only, via a head-bound adjudication line; the driver never writes it.

### Reviewer routing when the driver is the mandatory reviewer (finding K)
`models.md` requires reviewer ≠ driver. When the configured default reviewer equals the driver
engine, select a different available engine (Claude/OpenCode/Codex as available); if none is
available, apply the documented single-engine waiver in `ship-gates.md` and record it — never let
the driver self-review.

### Reviewer/council spawn must be prompt-free on the driver engine (finding F)
The loop's most-repeated autonomous action is spawning the *other* engine's CLI (`claude -p …`,
`codex exec …`, `opencode run …`). On Codex/OpenCode this can trip the driver engine's approval
policy and silently stall each round. The skill therefore **requires** the driver engine's
approval config to pre-allow reviewer/council spawns (documents the exact `.codex/config.toml` /
`opencode.json` allow-entries), **or** honestly states that full unattended autonomy is
Claude-only and the run degrades to a per-round prompt on the other engines. No silent stall.

---

## 7. Per-engine execution + failure handling

- **Execution mode** per `execution.md`: **subagent-driven on Claude Code**, **inline** on
  Codex/OpenCode. `/goal` never changes the engine-neutral core.
- **Implementers are NON-committing (review finding E/P1-E).** `execution.md`'s default subagent
  commits per task, but `ship-gates.md` forbids `git commit` before all standard gates are green.
  Under `/goal`, implementers **stage only** (no commit) and report back; `/goal` performs the
  single commit at the ship transition once gates are green. (This is a `/goal`-scoped override of
  the subagent commit behavior; state it explicitly and consistently for all engines — inline mode
  likewise does not commit mid-loop.)
- **Tool/subagent failure:** retry once → if still failing and recovery is a judgment call →
  `council`; else **HALT** with a `## Blockers` line + `status=halted`.
- **`ask`-tier commands (`rm -rf`, etc.):** an autonomous loop cannot self-approve the native
  prompt, so such a command silently stalls. The skill instructs preferring prompt-free
  alternatives (cache flags, `: >` truncation instead of `rm`) and announcing any unavoidable
  recursive delete in-conversation first (mirrors the origin `workflow.md`).

---

## 8. Enforcement model (honest — the identity; review findings G, I)

- **`check-gates.sh` is a terminal, full-profile validator, not a per-phase checkpoint.** It
  validates the entire standard-profile checklist (identity + count) and exits non-zero if any
  required box is unchecked/not-N/A — so it can only pass at the **ship transition**. The driver
  runs it **only before shipping**. Intermediate phase progress is tracked by the `## /goal loop`
  `phase`/`status` fields and is **Advisory**, not Attested. (Corrects the earlier claim that
  check-gates runs "at each phase transition.")
- **Ship-gate red path (finding G/P1-5):** if `check-gates` is red at the ship transition, the
  driver returns to the owning phase to green it; if the **same** transition fails twice, it
  **HALTs** with a `## Blockers` line and `status=halted` (deterministic red is not retried
  forever and is not sent to `council`).
- **CI honesty (finding I/P1-8):** the skill reuses the **exact conditional wording** from
  `ship-gates.md` — the Fase 1 CI template (`docs/ci-templates/gates.yml`) is **inert until
  copied into `.github/workflows/`, its test step filled, and made a required status check**, and
  becomes bad-faith-**resistant** only with the full activation (CODEOWNERS on the workflow and
  test-defining files, dismiss-stale-approvals, strict/up-to-date checks or a merge queue, bypass
  disabled for admins). It is **not** described as "the hard gate" unconditionally.

Honesty block (must appear in the skill body): *"This autonomy is discipline plus a terminal
Attested checkpoint, not a runtime hard gate. Intermediate phase progress is Advisory. On all
three engines the only bad-faith-resistant gate is the fully-activated Fase 1 CI template.
`/goal` does not, and cannot, block a bad ship locally."*

---

## 9. Landing checklist (linter / evals / tests)

- `src/skills/goal/SKILL.md` — full **anti-rationalization anatomy** (`## Common rationalizations`
  + `## Red flags` + `## Verification`, HARD-required by `tools/lint-skills.mjs`). Body includes
  the phase-ownership contract (§3), the portable GATE 2 rule (§5), the bounded-convergence rule
  (§6), non-committing implementers (§7), and the honesty block (§8).
- `src/CLAUDE.md` — add `goal` to the "Workflow skills" index (index parity is a linter hard
  error).
- `tools/run-evals.mjs` fixture — routing/collision cases for `/goal` (rank-1 ≥ floor); must not
  collide with `new-feature`/`fix-bug`; include a **bug objective → route to /fix-bug** rejection
  case if the eval harness models it.
- `src/shared/state.template.md` — add the `## /goal loop` section (INACTIVE by default:
  heading + empty-value table) **and the `## Blockers` section** (currently absent).
- `src/shared/rules/workflow.md` — add a `/goal` row to "Which skill" + a short "autonomous run"
  note (two explicit gates, council routing, bounded convergence, honest non-enforcement).
- Tests (`tools/test/*.test.mjs`, `node --test`, zero-dep): cover the state-update helper's
  REPLACE + `## Review log` append + resume-decision logic (halted/awaiting/continue); assert the
  skill passes the linter and the eval routes `/goal` rank-1; assert bug objectives are rejected.
  Extend `tests/smoke.sh` expected-skills list to include `goal`.
- `docs/CHANGELOG.md` — add under `## Unreleased`. Per the user's instruction this stays on
  v0.6.0; no separate release is cut for it now.

---

## 10. Open questions for the plan (all v1-blocking ones resolved)

- Exact `N` for the convergence breaker (default 4) — tune during implementation against real
  runs; make it a named constant, not a magic number.
- Exact allow-entry syntax to pre-approve reviewer/council spawns in `.codex/config.toml` /
  `opencode.json` (§6, finding F) — verify against current Codex/OpenCode config schemas in the
  plan's research step.
- Whether the state-update helper lives in `tools/` (dev-only) or `shared/scripts/` (ships to
  targets) — it must ship, since `/goal` runs in targets, so likely `shared/scripts/` with tests
  in `tools/test/`. Confirm in the plan.

Resolved inline: v1 scope (feature-only), bug rejection/routing, GATE 1 durable record, GATE 2
portability, convergence-breaker semantics, check-gates placement + red path, CI honesty wording,
`## Blockers` section, `simplify` placement, reviewer routing.

---

## 11. How this proceeds (process)

1. **Human spec-review gate** (this revised file), then adjust inline.
2. `superpowers:writing-plans` → implementation plan (task list + test stubs).
3. **Cross-engine plan review** (Opus + Codex `gpt-5.6-sol` + OpenCode `kimi-k3`) — mandatory.
4. `superpowers:subagent-driven-development` — per-task impl + review; final whole-branch review
   (Opus + Codex) before PR.
5. PR `feat/goal-autonomous` → `dev`. Stays on v0.6.0 (no release cut now, per user).

---

## 12. Spec review log

- **Design-spec review iteration 1 — 3 engines — 2026-07-22.** Opus (subagent) + Codex
  `gpt-5.6-sol` (xhigh, read-only) + OpenCode `kimi-k3`, focused on real structural/portability/
  honesty defects (not nitpicks). Strong convergence. Findings resolved in this revision:
  - **P0-A** (all 3) — convergence-breaker was dead code (certification = exit, so "past-cert"
    never happens; non-converging loop never certifies) → rewrote §6: rounds-from-start, breaker =
    HALT if not certified within N, content-digest binding, `simplify` before certification.
  - **P0-B** (all 3) — GATE 2 delegated to bypassable native prompt → §5 now requires explicit
    driver-issued approval on all three engines; native prompt is defense-in-depth only.
  - **P1-C** (Codex, ✓code `new-feature §0`) — no composition contract → §3 phase-ownership matrix.
  - **P1-D** (all 3) — resume state insufficient/duplicated → §4 adds `status`, `gate1` record,
    `step` cursor, nonce-clear, single authoritative phase, `## Blockers` section + resume rules.
  - **P1-E** (Codex, ✓code `execution.md`) — subagent per-task commit vs ship-gates → §7 non-
    committing implementers.
  - **P1-F** (Opus) — reviewer/council CLI spawn stalls autonomy on Codex/OpenCode → §6 pre-allow
    requirement or honest Claude-only-autonomy degradation.
  - **P1-G** (all 3) — check-gates is terminal, not per-phase; red path undefined → §8 rewrite.
  - **P1-H** (all 3) — bug path unspecified → §1 feature-only v1 + explicit bug rejection/routing.
  - **P1-I** (Codex) — CI honesty overclaim → §8 exact conditional wording from ship-gates.md.
  - **P1-J** (kimi) — resume could revive a halted loop → §4 `status=halted` + resume STOP rule.
  - **P2-K** (Codex) — reviewer routing vs Codex driver → §6 non-driver selection + waiver.
  - **P2-L** (kimi) — enum omitted `simplify` → §4 enum includes it (resume-granularity sub-step).

  Raw reviewer outputs archived in the session scratchpad (not committed).
