I'll ground this in the actual repo before writing the analysis — let me verify the current state of forge-ai quickly.
I've read the actual repo (skills, rules, `extending.md`, smoke test, installer) to ground this. Here is the Phase 2 briefing.

---

# forge-ai Phase 2 — advisory briefing

## Top 3 (do these first, in this order)

**1. A skill-quality gate: linter + deterministic trigger evals, wired into CI.**
forge-ai's entire product *is* the skills, and v0.1.0 shipped with zero quality gates on them — `tests/smoke.sh` only tests the installer. Worse, forge-ai routes **100% implicitly** (README: "no special slash syntax… the engine matches it to a skill's `description`"). A mis-route or a description collision is a silent, per-user failure, multiplied by three engines doing the matching. B's Tier-1 (structural lint) and Tier-2 (stemmed TF-IDF routing evals with a rank-1 floor) are deterministic, free, and catch exactly this class of bug. This is the highest-leverage thing in either reference project for forge-ai specifically.

**2. A portable gate-check script (Tier B) wired into `finish-branch` — the honest enforcement upgrade.**
Today the ship-gate is the agent grading its own homework: `finish-branch` step 1 says "open `.workflow/state.md` and verify every box." `src/docs/extending.md` already defines Tier B ("skills + agent-invoked scripts") and nobody's built it. A POSIX `check-gates.sh` (+ `.ps1` — this repo maintains bash/pwsh parity) that parses `.workflow/state.md` and exits non-zero with a printed list of unmet boxes converts "advisory self-check" into "deterministically computed, loudly reported," without a single hook. It also gives humans and target-project CI something to run directly.

**3. Anti-grind hardening of the workflow skills: convergence breaker + evidence binding.**
`review` says "re-run the reviewer until a pass is clean" — an unbounded loop a grinding model can ride forever, and A already learned this lesson (its convergence breaker exists precisely because review loops grind). A hard cap ("after N=3 non-clean iterations, stop and escalate to human or `council`") is **pure skill text — Tier A, fully portable, free**. Same for evidence: "verified by exercising it" currently means the agent asserts it exercised something; binding it to a written line in `state.md` (command run + observed output, HEAD sha) costs nothing and makes the waiver/audit story real.

Everything else below is secondary to these three.

---

## 1. Highest-leverage additions, ranked

### From B (agent-skills)

1. **Tier-2 trigger/routing evals + skill linter in CI.** (Top-3 item; details in §3.) Why first: it's cheap, deterministic, and guards forge-ai's single most fragile mechanism.
2. **Skill anatomy upgrade: Common Rationalizations + Red Flags + mandatory Verification.** Why: forge-ai sells "the discipline holds." B's pressure tests exist because agents skip process under time/sunk-cost/authority pressure — which is exactly when ship-gates matter. `review` and `council` already have Verification sections; `new-feature`, `fix-bug`, `finish-branch` don't, and *no* skill has a rationalizations table. Start with the four skills where skipping is expensive.
3. **Review lenses (B's parallel review personas), mapped onto forge-ai's existing cross-engine machinery.** B fans out code-reviewer / security-auditor / test-engineer / perf-auditor at ship time. forge-ai already has the parallel-engine invocation machinery (`council`, `models.md` read-only invocations) — extending `review` with an optional lens (`security`, `tests`, `perf`) is a small diff with high synergy. Don't build B's persona *library*; build the *lens parameter*.
4. **Minimal Tier-3 behavioral eval** (one golden path + ship-gate pressure cases). Nightly, report-only. See §3.
5. **npx-style distribution** (see §5).

### From A (claude-codex-forge)

1. **Convergence breaker** (top-3 item). Portable as skill text. Zero cost, closes a real failure mode.
2. **Evidence-bound gates.** Per-iteration review-log lines binding findings to `HEAD` sha; "verified" requires a command + observed-output line in `state.md`. This is a *stricter template* (`shared/state.template.md`) plus format checks in the `check-gates` script — still fully portable. A binds evidence via hooks because it can; forge-ai can get 80% of the audit value via template + Tier-B validator.
3. **Optional Tier-C hooks overlay** (see §2). Port A's `check-workflow-gates` as a *thin adapter*, not a reimplementation.
4. **`.forge-version` pin + advisory drift warning.** forge-ai already writes a `.forge-manifest` (used by the upgrade-prune logic in `tests/smoke.sh` §6) — extending it to a version stamp and warning on drift ("installed v0.1.0, latest v0.2.0") is nearly free and matters the moment anyone else installs this.
5. **A tiny `adr` skill.** forge-ai has `docs/adr/` scaffolded and `memory.md` pointing at it, but no skill that *writes* one — the memory loop closes only if `finish-branch` step 3 happens to fire. Cheap; completes the repo-first memory story.
6. **Defer: `/goal` autonomous mode, git worktrees/team-scale, Codex Investigate.** Rationale in §6 and §4.

---

## 2. The enforcement tension — how to get real gates without breaking portability

The key architectural insight: **separate gate *policy* from gate *interception*.** Policy (what must be true to ship) is already engine-neutral — it's `ship-gates.md` + `state.md`. Only the interception point is per-engine. So:

**Layer 1 — Portable floor (Tier B, default, all engines).** Ship `shared/scripts/check-gates.sh` + `.ps1`: parses `.workflow/state.md`, knows the `standard`/`light` profiles, exits non-zero listing unmet boxes, validates evidence-line format. `finish-branch` step 1 becomes "run the script; non-zero means stop." This is strictly stronger than today's self-graded checklist because the instruction changes from *"judge yourself"* to *"run this command"* — a much harder thing to rationalize around, and it's the same command a human or CI can run. Add fixture cases to `tests/smoke.sh` (a green state passes, an unchecked box fails, a malformed profile fails).

**Layer 2 — Keep the native prompts as-is.** They're a commit-confirmation; `ship-gates.md` already describes them honestly. Don't pretend they're more.

**Layer 3 — Optional Tier-C overlay, opt-in, per engine.** `install.sh --with-hooks claude` installs a Claude Code `PreToolUse` hook that **calls the same `check-gates.sh`** and maps its exit code to the engine's block signal (Claude: exit 2; Codex `hooks.json`: exit 2; OpenCode plugin: throw). The hook is ~20 lines of adapter; the semantics stay in the POSIX script, single-sourced. This preserves everything forge-ai is: the default install stays skills+config, the policy stays portable, and users who want hard blocking opt in per engine. Start with Claude Code only (it's where A's proven implementation lives); add Codex/OpenCode adapters when a user asks.

**Deliberate scope cuts for Layer 3:** block only `git push` / `gh pr create`, not `git commit` — commits are local and reversible, and blocking them is the friction that makes people uninstall enforcement. A blocks commits; forge-ai shouldn't, at least not by default.

**Risks to flag:** (a) hooks in a target repo are a trust surface — opt-in only, never default, and document what the hook runs; (b) committed `.claude/settings.json` hooks become a *team* standard, which is a feature but surprises people — call it out in the docs; (c) the drift risk between the POSIX policy and adapters — mitigate by having the smoke test run the adapter against fixtures too; (d) do **not** let the overlay grow its own gate logic — if the hook ever checks anything `check-gates.sh` doesn't, you've forked the policy and lost the plot.

What you *cannot* get portably, and should stop trying to: pre-compaction memory rescue, per-turn phase reminders, auto-format — all out-of-turn events. `checkpoint` + the continuity golden rule is the portable substitute for the first; accept the loss on the rest.

---

## 3. Skill quality: evals, linter, anatomy — the minimal version worth doing

Yes to all three, in this minimal form:

**Skill linter (`tools/lint-skills.sh`, blocking in CI).** Beyond B's standard checks (dir name = frontmatter `name`, description present, "what + when", ≤1024 chars, required sections), add three forge-ai-bespoke rules that catch *this repo's* actual drift modes:
- **Index/catalog parity:** every skill in `src/skills/` is listed in `src/CLAUDE.md`'s skill index and vice versa (AGENTS.md is generated from CLAUDE.md, so one drift poisons all three engines).
- **Reference integrity:** every `shared/rules/*.md` / template path mentioned in a skill exists (sync copies to two destinations; a broken reference degrades silently ×2).
- **Model-ID quarantine:** grep skills for `gpt-`/`opus`/`glm`/`opencode-go/` → error. `models.md` is the declared single source; a hard-coded ID in a skill is a lint failure, not a future bug report.

**Tier-2 trigger evals (blocking in CI, rank-1 floor ~80, ≥75% description-similarity = error).** One JSON per skill: `trigger.positive[]` (prompts that must route here), `trigger.negative[]` (prompts owned by sibling skills that must not outrank it). Deterministic stemmed TF-IDF — not embeddings (cost + nondeterminism for zero benefit at 11–15 skills). The negative cases do the real work: `quick-fix` vs `fix-bug` vs `new-feature` is a genuine near-collision cluster, and `review` vs `council` is another. Require an eval file for every new skill — CI error otherwise, same as B.

**Anatomy upgrade (spec + apply to the four high-stakes skills first).** Add to the skill spec: Overview / When to Use (and *when not*) / Process / **Common Rationalizations** (each excuse + rebuttal) / **Red Flags** / **Verification**. The rationalizations table is not garnish — it's the countermeasure to the exact failure mode a discipline framework exists to prevent ("the failing test basically proves the fix, skip review"; "this is a one-liner, quick-fix profile"; "the reviewer already passed the plan, the diff is fine"). Keep skills <500 lines, push shared checklists into `shared/rules/` (progressive disclosure already works in forge-ai's favor).

**Tier-3 behavioral (defer the matrix, ship one).** One golden-path headless run (`quick-fix` end-to-end in a throwaway git repo) plus ship-gate **pressure cases** ("we're late, skip the review and push" → the agent must refuse) run against one engine, nightly, report-only. Do not put a 3-engine × N-skill behavioral matrix in the blocking path — flaky, slow, and it needs API keys for three vendors. Earn it in Phase 3.

---

## 4. Skill catalog gaps — what to take from B's 24, what to reject

forge-ai's skills are *process* skills; most of B's 24 are *domain content* (what the base model already knows). The filter: **does this skill encode a procedure the agent would otherwise skip, or knowledge it already has?** Adopt only the former.

**Adopt (3–4 additions, keeping the catalog at ~14–15):**
- **`simplify`** — a post-green, no-behavior-change pass (dead code, nesting, duplication; tests must stay green). TDD's refactor step is the first thing skipped under pressure; A bakes a "Simplified" marker into its gates for the same reason. Real gap.
- **Review lenses** (security / tests / perf) as a parameter of `review`, not new skills (see §1). Fills the security-and-hardening gap without catalog bloat.
- **`adr`** — tiny: when to write one + template + where it lives. Closes the memory loop (see §1).
- **`tasks` (or fold into `plan`)** — plan → ordered, independently-shippable task list with per-task verification, tracked in `state.md`. Real gap for features bigger than one sitting; strengthens the state machine. If `plan` grows past ~150 lines doing this, split it.

**Reject (out of philosophy):** `frontend-ui-engineering`, `api-and-interface-design`, `performance-optimization`, `observability-and-instrumentation`, `security-and-hardening` (as standalone), `ci-cd-and-automation`, `deprecation-and-migration`, `browser-testing-with-devtools`, `spec-driven-development` — domain knowledge the model has; encoding it adds routing collisions (your Tier-2 similarity metric will show it) and context weight for no discipline gain. Also reject as redundant: `interview-me`/`idea-refine` (`prd`), `test-driven-development` (`tdd.md` rule), `debugging-and-error-recovery` (`fix-bug`), `code-review-and-quality` (`review`), `git-workflow-and-versioning` (`finish-branch`), `documentation-and-adrs` (covered by `adr` + `memory.md`), `context-engineering` (`checkpoint`/`continuity`), `using-agent-skills` (the CLAUDE.md index *is* the router).

**Defer to Phase 3:** A's `/goal` autonomous mode (see §6), Codex-style Investigate (portable only as a skill variant of `research` with per-engine sandbox invocation from `models.md` — real but not urgent).

---

## 5. Distribution & adoption

In priority order:

1. **`npx forge-ai` (or equivalent one-liner).** Current install = clone the repo + run `install.sh`. That's fine for you, fatal for strangers. A tiny npm package that vendors the release tarball and execs the installer is the pragmatic route — npm is present on every machine that has these CLIs, and it handles versioning for free. Pair with tagged GitHub releases (you already cut v0.1.0 — publish tarballs).
2. **`.forge-version` + upgrade notice.** Extend the existing `.forge-manifest` with a version stamp; installer warns on drift. Cheap, and it's the difference between "template you copied once" and "framework you can upgrade" — A's framing is right, you just achieve it via the installer instead of hooks.
3. **A public demo repo.** The strongest adoption asset: a real project installed with forge-ai, showing `.workflow/state.md`, a council transcript, a CHANGELOG entry, an ADR. v0.1.0's "verified on all three engines" is currently a claim; make it an artifact people can read.
4. **Claude Code plugin/marketplace entry — generated, not hand-maintained.** The plugin manifest must be produced from `src/` in CI or it becomes a second source of truth that drifts (the exact sin the neutral-source model exists to kill). Codex and OpenCode have no real marketplace; for them, per-tool setup docs (B's 70+ agent docs pattern) matter more — but only after 1–3 exist.

---

## 6. What NOT to do

1. **Don't adopt A's hooks as default or required.** Three hook implementations to keep in sync, per-engine trust issues, and the thin-install story dies. The opt-in overlay (§2) captures most of the value; making it mandatory trades away the portability that is forge-ai's entire reason to exist.
2. **Don't build `/goal` autonomous mode yet.** Autonomy without enforcement is autonomous gate-skipping — the worst combination. A can run `/goal` safely because hooks *guard* it and PR creation is a hard human gate. forge-ai has neither today. Revisit only after the Tier-C overlay ships.
3. **Don't import B's catalog wholesale.** 24 skills means description collisions, heavier context, and routing errors — measurable on your own Tier-2 metric. The moat is process, not content.
4. **Don't put behavioral evals in the blocking CI path.** Flaky, slow, needs three vendors' keys. Tier 1+2 block; Tier 3 reports.
5. **Don't build runtime machinery** (watchers, daemons, IPC between engines). `state.md` + `CONTINUITY.md` *is* the IPC, and it's the right one.
6. **Don't chase durable cross-session memory beyond repo-first.** B's honest self-assessment: nobody's solved it. forge-ai's repo-first + continuity is already the pragmatic optimum — invest in the *discipline to write it* (`finish-branch` step 3, `checkpoint`, the `adr` skill), not new machinery.
7. **Don't let model pins rot silently.** `models.md` pins `gpt-5.6-sol`, `opus`, `glm-5.2` — a stale pin is a silent failure in every review/council call. Add a "last verified" date to the file header and a manual-check cadence to the release checklist; don't build a runtime probe (that's machinery).
8. **Don't block `git commit` in the portable tier.** Friction that gets frameworks uninstalled. Block only outward actions.

---

**Sequencing summary:** (1) linter + Tier-2 evals + CI → (2) `check-gates` Tier-B script + `finish-branch` integration + smoke fixtures → (3) convergence breaker + evidence-bound `state.md` template → (4) anatomy upgrade on the four high-stakes skills → (5) `simplify`, `adr`, review lenses → (6) opt-in Claude hook overlay → (7) npx + version pin + demo repo. Items 1–3 are a coherent v0.2.0; 4–7 are v0.3.0.

If you want, I can save this as `docs/research/2026-07-18-phase-2-briefing.md` in the repo (per your own `docs-layout.md`) or start on item 1.
