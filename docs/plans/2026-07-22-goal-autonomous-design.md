# codeforge `/goal` — autonomous mode (Fase 2) — design spec

**Written:** 2026-07-22. **Branch:** `feat/goal-autonomous` (off `dev`, v0.6.0).
**Status:** design approved; **revised 3× after cross-engine spec review** (Opus + Codex
`gpt-5.6-sol` + OpenCode `kimi-k3`) — see §14. §4/§6 now gate-ready; byte-level digest algorithm
deferred to the plan with enumerated tests (§12). Next: human spec-review gate → writing-plans.

Repo: `~/Desktop/personal/projects/forge-ai` (GitHub `Juan-Motta/codeforge`, npm
`@jualopezmo/codeforge`). Cross-engine (Claude Code / Codex / OpenCode) workflow-discipline
framework. `/goal` is the top capability gap vs the origin `claude-codex-forge`; a cross-engine
`/goal` is **unique**.

---

## 1. Goal

A resumable, mostly-autonomous driver taking a **single feature objective** from idea to a
PR-ready branch — `prd → research → plan → review → TDD → review → simplify → verify → PR` —
pausing for the human at **exactly two** planned points (entry + PR) plus any unplanned HALT.
Between the gates it runs autonomously; ambiguous forks → `council`; non-convergence and
unrecoverable failure → human HALT. It runs **identically on Claude Code, Codex, OpenCode**, which
requires a **capability preflight** (§6.4) before the first gate proving the loop's own autonomous
actions (cross-engine reviewer/council spawns) are prompt-free. If not provable, `/goal` HALTs
honestly rather than stalling on a per-round prompt.

Honesty: the two-pause guarantee is an **explicit driver-issued approval on all three engines**
(§5), never a bypassable native prompt. The autonomy is discipline; the only bad-faith-resistant
hard gate is the fully-activated Fase 1 CI template (§8).

### Scope (locked): **feature-only in v1**. Bug objectives are rejected at classification → `/fix-bug`.

### Non-goals (YAGNI)
No new hook/enforcement; no re-implementation of composed skills' phase logic; no third state file
(loop state in `.workflow/state.md`); no auto-approval of `ask`-tier prompts; no bug path in v1.

---

## 2. Decisions locked

| # | Fork | Decision |
| - | ---- | -------- |
| 1 | Enforcement | Discipline + `check-gates` at the SHIP transition only (Attested); intermediate progress Advisory. No new hooks. |
| 2 | Resume | Reuse `.workflow/state.md` (`## /goal loop` + `## Blockers` + `## Review log`) + `CONTINUITY.md`. A **mandatory tested** state helper owns atomic writes (§9); not an enforcement hook. |
| 3 | Human pauses | Entry (PRD) + PR only, explicit on all engines. Ambiguous → `council`; non-convergence / unrecoverable → human HALT. |
| 4 | v1 scope | Feature-only; bugs rejected → `/fix-bug`. |
| 5 | Autonomy precondition | Capability preflight (§6.4) before GATE 1, else HALT (no per-round-prompt degradation, no driver self-review). |
| 6 | Cross-session resume | **In scope for v1** — hence the durable, nonce+epoch-scoped record protocol (§10) and crash-safe resume (§4.2). |

Approach **A** — thin orchestrator composing existing skills under a phase-ownership contract
(§3), advancing a state machine (§4, §11). Rejected B (duplication) and C (no explicit ledger).

---

## 3. Architecture + composition contract

`/goal <objetivo>` → new `src/skills/goal/SKILL.md`, engine-neutral.

```
/goal <objetivo>
  → classify: feature | bug → bug: STOP, route to /fix-bug (v1)
  → CAPABILITY PREFLIGHT (§6.4): reviewer/council spawn prompt-free + non-driver reviewer exists;
        persist the expected-reviewer manifest. Fail → HALT (no autonomy).
  → prd            → GATE 1 (human, explicit, all engines): approve PRD ────────────────────┐
  → research       (only if external tech)                                                  │
  → plan-review LOOP: /goal orchestrates `review` over the plan doc (bounded — §6.2)         │ autonomous
  → tdd            (execution.md; implementers commit_policy=defer, stage-only — §7)         │  ambiguous → council
  → code-review LOOP (bounded, re-entrant — §6.2/§6.3):                                       │  non-convergence → HALT
        review rounds → first clean → simplify ONCE → one re-cert at post-simplify digest    │  unrecoverable → HALT
  → verify-e2e     (or N/A); if it changes code → new epoch, re-enter code-review (§6.5)      │
  → ship:  check-gates + digest match → write CHANGELOG → SINGLE COMMIT → GATE 2 ────────────┘
        GATE 2 (human, explicit, all engines) authorizes the COMMITTED head → push → PR → done
```

`simplify` is a **sub-step inside the code-review loop**, never a phase that flows to `verify`.

### Phase-ownership contract (mandatory in the skill body)

Composed skills run standalone: `new-feature §0` initializes `.workflow/state.md`; `new-feature
§7` / `finish-branch` own shipping (verified `new-feature/SKILL.md:14,56-60`). Contract:

- **`/goal` OWNS:** one-time state init (`## /goal loop` + `## Blockers`), all transitions, the
  `step`/`epoch` cursors, the two loops (§6), retries + durable counters (§7), the two gates, the
  single ship commit, the terminal transition. Subordinate skills run in **`owner=goal` mode**:
  contribute only their phase's work + named sections; MUST NOT re-init state, commit/push/PR, or
  self-cap a loop.
- **Plan-review loop:** `/goal` orchestrates the `review` skill directly over the plan doc (same as
  the code-review loop) — it does **not** delegate loop control to `plan` returning a flag
  (verified: `plan §3` delegates to `review §4`, which loops "until clean" with no numeric budget,
  emits free-form lines, returns prose — insufficient). Certification is **recomputed from durable
  §10 records**, never from an ephemeral flag.
- **`new-feature` / `finish-branch`** contribute phase content only; their standalone init (`§0`)
  and ship (`§7`) steps are disabled under `owner=goal`. §9 lists the exact skill + generator edits.
- On Claude, implementers run via `codeforge-implementer` with `commit_policy=defer` (§7).

---

## 4. State machine — `## /goal loop` + `## Blockers` in `.workflow/state.md`

`## /goal loop` is the **single authoritative** loop header (REPLACE semantics — §4.1); it does
NOT duplicate `## Active workflow.Phase` (superseded for the loop's duration).

```
## /goal loop

| Field     | Value                                                                     |
| --------- | ------------------------------------------------------------------------- |
| nonce     | <uuid-v4>            (empty ⇒ INACTIVE/terminal)                          |
| goal      | <one-line feature objective>                                              |
| status    | active | awaiting-gate1 | awaiting-gate2 | halted | done                  |
| phase     | preflight|prd|research|plan-review|tdd|code-review|verify|ship            |
| step      | <phase>:<N>/<M>      (task cursor /goal OWNS — §10)                       |
| epoch     | <k>                  (code-review re-entry counter, from 0 — §6.5)        |
| base_sha  | <merge-base SHA at kickoff; digest base — §6.1>                           |
| gate1     | <§10 gate1 record; empty until approved>                                  |
| issued_at | <ISO-8601-UTC>                                                            |
```

Per-round, per-blocker, per-attempt, gate2, adjudication, simplify-done, and reviewer-manifest
data are **fixed-schema lines** (§10), all carrying the current `nonce` so nothing leaks across
loops (§4.1).

### 4.1 Kickoff, REPLACE, collision, abandon (fix P0-γ, N10)

Kickoff REPLACEs `## /goal loop` **iff** `nonce` is empty. If a loop exists (`nonce` set), kickoff
**REFUSES** unless the human has written a matching abandon record and cleared the old loop:

- Abandon requires (a) `- [x] ABANDON nonce=<old> — <staged-tree disposition> — ts=<ts>` in
  `## Blockers`, (b) **every** `- [ ] BLOCKER nonce=<old>` line resolved or abandoned, and (c) a
  clean/dispositioned working tree.
- Only then may kickoff REPLACE the header AND **archive/strip all `nonce=<old>` lines** from
  `## Review log`, `## Blockers`, and `## Attempts`, so the new loop starts with zero inherited
  rounds/blockers/attempts. (All §10 counting filters by the current `nonce` regardless, as
  defense-in-depth.)

### 4.2 Resume procedure (fix P0-α, P1-5) — the part §9 tests

Read `.workflow/state.md` **with the Read tool** + `CONTINUITY.md`, then:

1. `nonce` empty OR `status=done` → **INACTIVE**; do not resume.
2. `status=halted`: if **every** `- [ ] BLOCKER nonce=<current>` is now `- [x]`-adjudicated
   (head+tree-bound, budget effect present — §10) → **release**: set `status=active`,
   `phase=<owning phase named in the blocker>`, apply the adjudication's budget effect (§6.2), then
   go to step 6. Else **STOP, report to the human** (do not resume). *(This makes halted a gate,
   not a terminal — nothing else clears `status=halted`.)*
3. `status=awaiting-gate1` → re-issue GATE 1.
4. `status=awaiting-gate2` → re-issue GATE 2 (§5).
5. `status=active` AND `gate1` empty: if `phase ∈ {preflight, prd, research}` → resume that phase
   (a valid PRD approval is not yet required). If `phase` is past `prd` with `gate1` empty → **HALT
   (corrupt state)**; never silently re-issue GATE 1 for an already-built feature.
6. `status=active` (gate1 valid or phase pre-`prd`) → continue from `phase`+`step`+`epoch`, never
   restarting a completed phase; intra-phase, continue from `step`.

### 4.3 Terminal
On PR creation: `status=done` **and** clear `nonce`. Empty `nonce` is the sole terminal signal.

---

## 5. Human gates (portable + content-bound — fixes P0-B, N9)

**GATE 1** — after `prd`, `status=awaiting-gate1`, explicit approval (`AskUserQuestion` on Claude;
plain prompt elsewhere). On approval write the §10 gate1 record (`ts + prd path + prd_digest`),
`status=active`. PRD digest mismatch later ⇒ re-gate.

**GATE 2** — ordered AFTER the single ship commit (fix P0-δ). Ship sequence: `check-gates` green +
`ship-tree digest == certification digest` → write CHANGELOG (an excluded, digest-neutral file —
§6.1) → **single commit** → `status=awaiting-gate2` → explicit approval on all engines → write the
§10 gate2 line (`nonce + action + committed head + tree_digest + branch + remote + ts`) → push →
PR → done. The driver **re-verifies head+tree_digest before EACH push and PR action**; mismatch
clears the auth, sets `awaiting-gate2`, re-issues. The native `ask`-tier prompt is defense-in-depth
only. Council routing / NON-triggers unchanged (ambiguous → council; non-convergence → HALT;
`council` fails → HALT).

---

## 6. Cross-engine review loops + bounded convergence

Two loops, both **/goal-orchestrated over `review`** (reviewer ≠ driver, `models.md`): **plan-review**
(over the plan doc) and **code-review** (post-TDD, reviewer(s) + self-pass over the code). The
expected-reviewer set (incl. the self-pass role) is fixed at preflight and persisted (§10); a round
certifies only when exactly that set is clean at one digest.

### 6.1 The certification digest (fixes N1, P0-ε; byte algorithm → §12)

Binds a pass to content, not HEAD (implementers stage-only; an uncommitted plan/diff shares one
HEAD). **Membership (normative):** the digest covers **every non-git-ignored path** — the tracked
`git diff <base_sha>` (staged+unstaged) **and every untracked non-ignored file** (not only "code":
the plan doc, PRD, migrations, configs, ADRs, tests all count) — with a **closed exclusion set**
applied to **both** the diff pathspecs and the untracked scan:

> EXCLUDE: `.workflow/**`, `docs/e2e/reports/**`, `CONTINUITY.md`, `docs/CHANGELOG.md`, `VERSION`,
> `package.json`/lockfiles (ship-metadata), and any reviewer/council scratch output (§6.4 pins
> reviewer output to stdout or an excluded path).

Each entry is **framed** (path bytes + mode + content length + content) so a rename, empty-file
add, or content repartition changes the digest. Computed **at pass start, before** the round's
review-log append. `base_sha` recorded at kickoff. The exact byte-level algorithm + determinism
(`LC_ALL=C`, `--no-renames`, untracked ordering, `git add -N` normalization so untracked files
render uniformly) is a **required plan task** (§12) with enumerated tests.

### 6.2 Bounded termination (fixes P0-A, N2, N6, P0-β cap)

- **Certification = the single exit condition:** first pass where the expected-reviewer set is all
  clean at one digest. Each round appends a §10 review-log line (`kind=round|recert|cert`,
  `nonce`, `loop`, `epoch`, `digest`).
- **Per-epoch breaker:** rounds are counted from **durable §10 lines filtered by current
  nonce+loop+epoch** where `kind=round` (recert/cert lines do NOT count — fix N3). If a loop has
  not certified within `N` counted rounds (default `N=4`, named constant), HALT. Budget is durable
  across resume (recomputed from the log), so a mid-loop crash cannot reset it.
- **Global cap (fix P0-β):** total code-review `kind=round` lines across **all epochs** of the
  current nonce ≤ `MAX_CODE_ROUNDS` (default `3·N`); exceeding it HALTs. This bounds a
  verify↔code-review ping-pong where each epoch certifies quickly but verify keeps changing code.
- **Plan-loop budget** is honored the same way — `/goal` counts plan-review rounds from the log, so
  a resumed plan review cannot restart at 0.
- **Release (fix N6):** human-only §10 adjudication line carrying an explicit budget effect —
  `budget=rounds-reset` (counted rounds for that loop+epoch → 0) or `budget=+K` (allowance becomes
  previous allowance + K) or `budget=unchanged` (non-breaker HALTs). Only rounds with `epoch >` the
  adjudication's epoch count thereafter. The latest adjudication for the current nonce supersedes.
  Resume applies it via §4.2.2.

### 6.3 `simplify` (fixes N3, P0-2 dirty-exit)

`simplify` runs **exactly once per loop lifetime** (not per epoch), immediately after the **first
clean pass**; record `- [x] SIMPLIFY done — nonce — digest — epoch — ts` (§10) so resume/re-entry
never re-runs it. Then **one re-cert pass** (`kind=recert`) at the post-simplify digest:

- re-cert **clean** and `digest-at-exit == digest-at-recert` → write `kind=cert`, exit to `verify`.
- re-cert **has findings** → return to normal review rounds (`kind=round`, consume N), simplify
  never re-runs, certification = the next clean pass at a stable digest (a fresh `recert` is not
  required once simplify is done). This gives the dirty post-simplify pass a defined, bounded exit.

### 6.4 Capability preflight (fixes N7, N8) — BEFORE GATE 1
Prove on the driver engine: (1) a non-driver reviewer is available (select a different engine if
the default equals the driver); (2) spawning it (`claude -p`/`codex exec`/`opencode run`) is
prompt-free under the current permission config; (3) reviewer/council output goes to stdout or an
excluded path (so it can't move the digest mid-round). Persist the expected-reviewer manifest.
Any failure → **HALT before GATE 1** with a `## Blockers` line. `/goal` never degrades to per-round
prompting, and never uses the `ship-gates.md` delayed-self-review waiver in autonomous mode (that
waiver's human branch is unavailable autonomously; self-review would hollow out certification — it
stays valid for interactive use only). Required allow-entries are documented for **all three**
engines (shipped `src/configs/claude/settings.json` has no Bash allow-list, so Claude needs entries
too); exact syntax → §12.

### 6.5 Cross-phase invalidation (fixes N5, P0-β) — conservative collapse
Certification is digest-bound. **Any post-certification change to a digest-covered path invalidates
it** (a single hash can't classify *what* changed, so the rule is conservative: treat any change as
requiring re-review). Concretely: if `verify-e2e`, or a §8 red-path fix, changes a digest-covered
path, the driver **increments `epoch`** and **re-enters the code-review loop** (simplify does not
re-run — §6.3), producing exactly one fresh certification at the new digest. The digest-covered set
is exactly §6.1 (code + plan doc + PRD + tests; ship-metadata excluded). Between final
certification and the ship commit the driver MUST touch only excluded files (CHANGELOG/VERSION),
keeping the ship tree digest-stable. The global cap (§6.2) bounds repeated re-entry.

---

## 7. Per-engine execution + failure handling

- Mode per `execution.md`: subagent-driven on Claude, inline elsewhere.
- **`commit_policy=defer` (fixes P1-E, N4):** `execution.md` + the generated `codeforge-implementer`
  agent gain a `commit_policy=per-task|defer` contract. Under `defer` (`/goal` use): implementer
  stages only after its task is green+accepted, does **not** commit, and reports `task-id + test
  evidence + before/after tree digest`; `/goal` writes `step=<phase>:<N>/<M>` and makes the single
  commit at ship. Generator (`cli/lib/apply.mjs`, verified to order a commit today) updated (§9).
- **Durable attempt counters (fix N11):** `- ATTEMPT <op/transition> — nonce — fingerprint — n=<k>
  — ts` lines (§10), incremented **before** each attempt, filtered by current nonce — a restart
  can't reset the budget.
- **Failure:** retry once (durable counter) → judgment-call recovery → `council`; else HALT
  (`## Blockers`, `status=halted`).
- **Unavoidable `ask`-tier command:** **HALT explicitly** and hand to the human — never launch a
  command that then blocks on a native prompt (announcing is not enough). Prefer prompt-free
  alternatives (cache flags, `: >` instead of `rm`).

---

## 8. Enforcement model (honest — fixes P1-G, N5 red path, P0-δ ordering)

- `check-gates.sh` is a **terminal, full-profile validator** (verified: whole standard profile by
  identity+count; can only pass at ship). Run **only before shipping**. Intermediate progress is
  **Advisory**.
- **Ship ordering (P0-δ):** `ship/active` → `check-gates` green AND `ship-tree digest ==
  certification digest` → write CHANGELOG → **single commit** → `awaiting-gate2` → GATE 2 authorizes
  the **committed** head → push → PR → `done`. The commit precedes GATE 2 so authorization binds a
  stable head.
- **Red path:** `check-gates` red → return to the owning phase. If the greening fix touches a
  digest-covered path → increment `epoch`, re-enter code-review (§6.5) — never carry a stale
  certification to ship. Non-code fix → re-green then re-ship. **Same transition twice** (durable
  counter) → HALT.
- **CI honesty:** exact conditional wording from `ship-gates.md` — the Fase 1 CI template is inert
  until copied/filled/required, bad-faith-resistant only with full activation (CODEOWNERS, stale-
  approval dismissal, strict checks/merge queue, admin bypass disabled). Never "the hard gate"
  unconditionally. Honesty block in the skill body as before.

---

## 9. Landing checklist (linter / evals / tests / skills / generator)

- `src/skills/goal/SKILL.md` — full anti-rationalization anatomy (Common rationalizations + Red
  flags + Verification, HARD-required by `tools/lint-skills.mjs`); body carries §3 contract, §5
  portable gates, §6 convergence + preflight, §7 defer, §8 honesty.
- `src/CLAUDE.md` — add `goal` to the Workflow-skills index (parity is a linter hard error).
- `src/skills/plan/SKILL.md`, `src/skills/review/SKILL.md` — add the `owner=goal` mode note: when
  driven by `/goal`, loop control + §10 logging belong to `/goal`; the skill contributes one
  review pass and its findings, does not self-loop or self-cap.
- `src/skills/new-feature/SKILL.md`, `src/skills/finish-branch/SKILL.md` — note that `§0` init and
  ship steps are disabled under `owner=goal` (or `/goal` composes only their phase bodies).
- `tools/run-evals.mjs` — `/goal` routing/collision cases (rank-1 ≥ floor; no collision with
  new-feature/fix-bug) + a bug-objective → `/fix-bug` rejection case.
- `src/shared/state.template.md` — add `## /goal loop` (INACTIVE), `## Blockers`, `## Attempts`.
- `src/shared/rules/execution.md` — add the `owner` + `commit_policy=per-task|defer` contract.
- `cli/lib/apply.mjs` — generated `codeforge-implementer` becomes `commit_policy`-aware (report
  task-id + evidence + before/after tree digest under `defer`, not a commit SHA); update its tests.
- `src/shared/rules/workflow.md` — add a `/goal` row + autonomous-run note.
- Tests (`tools/test/*.test.mjs`, `node --test`, zero-dep) — the **mandatory** state helper:
  `## /goal loop` REPLACE + collision refusal + post-abandon strip (§4.1); the §4.2 resume decision
  incl. the **halted-release gate** and the **gate1-empty scoping** (crash-before-prd vs
  built-feature-corrupt); §10 line parsers with nonce/loop/epoch/kind; digest membership +
  **framing tests (rename, empty-file, plan doc, config, split content)** and the exclusion set;
  the §11 table invariant test — **every reachable nonterminal state/event has ≥1 bounded exit and
  every table source is reachable**. Assert the skill lints + routes rank-1 + rejects bugs. Extend
  `tests/smoke.sh` expected-skills with `goal`.
- `docs/CHANGELOG.md` — under `## Unreleased`; stays on v0.6.0 (no release cut now, per user).

---

## 10. Data schemas (normative; byte-level digest algorithm in §12)

Single-line, fixed-order, helper-parseable. **All loop-scoped lines carry `nonce`.**

- **Task cursor** (`## /goal loop.step`): `<phase>:<N>/<M>`.
- **gate1** (`## /goal loop.gate1`): `approved ts=<ts> prd=<path> prd_digest=<sha256>`.
- **gate2** (`## /goal loop`): `- [x] GATE2 authorized — nonce — action=push+pr — head=<committed
  sha> — tree_digest=<digest> — branch — remote — ts`.
- **Reviewer manifest** (`## /goal loop` or `## Review log`): `- REVIEWERS nonce — set=<engine,…,
  self> — ts` (fixed at preflight; certification requires exactly this set clean).
- **Review-log line** (`## Review log`): `- nonce — loop=plan|code — epoch=<k> — round=<N> —
  kind=round|recert|cert — reviewer=<engine|self> — result=clean|P0=a/P1=b/P2=c — digest — ts`.
  Certification digest = the digest on the latest `kind=cert` line for the current nonce+loop.
- **SIMPLIFY marker** (`## /goal loop`): `- [x] SIMPLIFY done — nonce — digest — epoch — ts`.
- **Blocker** (`## Blockers`): unresolved `- [ ] BLOCKER <id> — nonce — phase — reason —
  tree_digest — ts`; resolved (human) `- [x] BLOCKER <id> — nonce — ADJUDICATED — decision —
  budget=rounds-reset|+K|unchanged — epoch=<k at halt> — head — tree_digest — ts`.
- **Attempt** (`## Attempts`): `- ATTEMPT <op/transition> — nonce — fingerprint — n=<k> — ts`.
- **Abandon** (`## Blockers`): `- [x] ABANDON nonce — <staged-tree disposition> — ts`.

---

## 11. State transition table (normative — every source reachable, every nonterminal has an exit)

| # | From (phase/status) | Event | To | Writes |
|---|---|---|---|---|
| 1 | (no loop) | `/goal <feature>` | `preflight` / `active` | init `## /goal loop` (refuse if nonce set — §4.1), `base_sha`, `epoch=0` |
| 2 | (no loop) | `/goal <bug>` | (none) | STOP → `/fix-bug` |
| 3 | `preflight`/`active` | preflight OK | `prd` / `awaiting-gate1` | REVIEWERS manifest |
| 4 | `preflight`/`active` | spawn prompts / no non-driver reviewer | `halted` | `## Blockers` |
| 5 | `prd`/`awaiting-gate1` | human approves | `research`\|`plan-review` / `active` | gate1 record |
| 6 | `prd`/`awaiting-gate1` | human declines | `prd` / `active` | revise PRD, re-issue GATE 1 |
| 7 | `research`/`active` | done | `plan-review` | — |
| 8 | `plan-review`/`active` | round with findings, counted<N | `plan-review` | review-log `kind=round` |
| 9 | `plan-review`/`active` | clean pass (cert) | `tdd` | review-log `kind=cert` |
| 10 | `plan-review`/`active` | N exceeded | `halted` | `## Blockers` |
| 11 | `tdd`/`active` | task k green+accepted | `tdd` | `step=tdd:k/M` (stage only) |
| 12 | `tdd`/`active` | all tasks done | `code-review` | — |
| 13 | `code-review`/`active` | round with findings, counted<N | `code-review` | review-log `kind=round` |
| 14 | `code-review`/`active` | first clean pass | `code-review` (simplify sub-step) | review-log; SIMPLIFY marker |
| 15 | `code-review`/`active` | re-cert clean, digest stable | `verify` | review-log `kind=cert` |
| 16 | `code-review`/`active` | re-cert has findings | `code-review` | review-log `kind=round` (simplify done) |
| 17 | `code-review`/`active` | N exceeded (this epoch) OR global cap exceeded | `halted` | `## Blockers` |
| 18 | `verify`/`active` | changes a digest-covered path | `code-review` | `epoch++`, invalidate cert (§6.5) |
| 19 | `verify`/`active` | pass / N/A | `ship` / `active` | evidence |
| 20 | `ship`/`active` | check-gates green AND ship-tree==cert digest | `ship` / `awaiting-gate2` | CHANGELOG, single commit |
| 21 | `ship`/`active` | check-gates red, fix touches digest path | `code-review` | `epoch++`, invalidate cert |
| 22 | `ship`/`active` | check-gates red, non-code fix | owning phase → re-ship | attempt line |
| 23 | `ship`/`active` | same transition twice red | `halted` | `## Blockers` + attempt |
| 24 | `ship`/`awaiting-gate2` | human approves | `ship` / `active` (push→PR) | gate2 line |
| 25 | `ship`/`awaiting-gate2` | gate2 re-verify head/tree mismatch | `ship` / `awaiting-gate2` | re-issue GATE 2 |
| 26 | `ship`/`active` | PR created | `done` (nonce cleared) | — |
| 27 | any/`active` | unrecoverable / ask-tier unavoidable / council fails | `halted` | `## Blockers` + attempt |
| 28 | `halted` | all current-nonce blockers adjudicated (§4.2.2) | owning phase / `active` | `status←active`, apply budget |

---

## 12. Open questions for the plan (v1-blocking resolved in-spec)

- **Byte-level digest algorithm** implementing §6.1 membership+framing: exact `git diff` exclude
  pathspecs, `git add -N` normalization, untracked ordering, `LC_ALL=C`, `--no-renames`, and the
  hash framing (path+mode+length+content). Ship it as a tested function with cases: rename,
  empty-file add, plan-doc edit, config edit, content split/concat, staged↔untracked transition.
- Exact reviewer/council pre-allow syntax for `.claude/settings.json` / `.codex/config.toml` /
  `opencode.json` (§6.4) — verify against current schemas in the plan's research step.
- Constants: `N=4`, `MAX_CODE_ROUNDS=3·N` — tune against real runs; named constants.
- State-helper home: `shared/scripts/` (ships to targets) with tests in `tools/test/`. Confirm.

---

## 13. Process
1. Human spec-review gate (this file) → adjust inline.
2. `superpowers:writing-plans` → plan (task list + test stubs; §10 schemas + §11 table as testable
   units; digest function with the §12 test cases).
3. **Cross-engine plan review** (mandatory).
4. `superpowers:subagent-driven-development` → per-task impl + review; final whole-branch review
   (Opus + Codex).
5. PR `feat/goal-autonomous` → `dev`. Stays v0.6.0.

---

## 14. Spec review log

- **Iter 1 (whole spec) — 3 engines.** 2 P0 + 8 P1 + 2 P2; resolved in revision 1.
- **Iter 2 (§3–§8) — 3 engines.** 7–8 iter-1 findings CLOSED; 11 new P1 (3 P0-class); resolved in
  revision 2 (operational contract + §10 schemas + §11 table).
- **Iter 3 (§4/§6/§10/§11) — 3 engines.** §4 core declared sound (Opus). §6 not yet: consensus
  3 P0 + several P1, all small/local, no reopened decisions. Resolved in **this** revision
  (revision 3):
  - **P0-α** halted never exits → §4.2.2 halted-release gate + §11 row 28 (`status←active`).
  - **P0-β** code-review re-entry undefined (can't-exit / unbounded) → §6.5 epoch + §6.2 global
    cap `MAX_CODE_ROUNDS` + §6.3 simplify-once-per-lifetime + §11 rows 16/18/21.
  - **P0-γ** cross-loop contamination → §4.1 post-abandon strip + `nonce` on all §10 lines +
    filter-by-nonce counting.
  - **P0-δ** ship ordering (GATE 2 before commit) → §5/§8/§11: commit precedes `awaiting-gate2`.
  - **P0-ε** digest membership/framing → §6.1 all-non-ignored + closed exclusion (both clauses,
    incl. ship-metadata) + path/mode/length/content framing + plan doc/PRD bound; byte algorithm +
    tests → §12.
  - **P1** plan-loop breaker not landed → §3/§9: `/goal` orchestrates `review` for both loops;
    plan/review/new-feature/finish-branch skill edits added to §9. `kind` field for "doesn't
    consume N" (§10). gate1-empty crash misfire → §4.2.5. §11 exhaustiveness + reachability test
    (§9). Reviewer manifest persisted (§6.4/§10). Adjudication bound to tree_digest+epoch (§10).
  - P2 folded: `status=done` terminal; ship digest-neutral between cert and commit; latest
    adjudication supersedes; digest determinism pinned in §12.

  Byte-level digest algorithm is the only item deferred to the plan (with enumerated tests), per
  the user's decision to close prose-review here and operationalize the remaining precision as
  tested code under the mandatory cross-engine **plan** review.

  Raw reviewer outputs archived in the session scratchpad (not committed).
