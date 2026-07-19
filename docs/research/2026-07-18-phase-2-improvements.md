# Phase 2 research — how to improve forge-ai

**Date:** 2026-07-18
**Method:** multi-engine analysis. The same briefing (current forge-ai state + two reference
projects) was handed to four separately-trained models; this document synthesizes their
verdicts and flags where they diverge.

| Engine | Model | Notes |
| --- | --- | --- |
| Claude Code | Opus 4.8 (high) | driver / synthesis |
| Codex | gpt-5.6-sol (xhigh) | 508-line analysis |
| OpenCode | opencode-go/glm-5.2 | read the real repo before writing |
| OpenCode | opencode-go/kimi-k3 | read the real repo; caught the most forge-ai-specific detail |

Reference projects analyzed:
- **A — `pablomarin/claude-codex-forge`** (v5.56): the rich ancestor forge-ai forked from —
  full Claude-Code hooks enforcement, `/goal` autonomous mode, Codex Investigate, 5-advisor
  Council, evidence gates, convergence breaker, ADRs, Diátaxis docs.
- **B — `addyosmani/agent-skills`** (79k★): 24 lifecycle skills, a **three-tier eval framework**
  (structural / routing / behavioral with pressure cases), a **skill linter**, the
  anti-rationalization + Red-Flags skill anatomy, shared reference checklists, and
  plugin/marketplace + `npx skills` distribution across 70+ agents.

---

## The verdict: Phase 2 is a *trustworthiness* release, not a catalog-expansion release

All four engines converged on the same thesis, independently: forge-ai's differentiator is a
portable, cross-engine workflow discipline whose enforcement is **advisory**. That means the
skills ARE the product, and forge-ai currently has **no way to know whether its skills work** —
no linter, no routing test, no evals, no CI (only `tests/smoke.sh`, which tests the installer).
Fix that before adding anything.

The strongest single framing (Codex): distinguish what forge-ai can honestly claim —
**Verified** (an out-of-turn check recomputed the fact) vs **Attested** (an agent/human claimed
it and forge-ai only validated the *shape*) vs **Advisory** (present only as an instruction).
Today's self-checked `state.md` boxes are *attested*, not enforced. A JSON file saying
`reviewer_engine: codex` is not proof Codex reviewed anything. **Never market a checkbox as a
gate.** glm independently flagged that the current README's "best-effort native prompt" language
already over-sells — tighten it now, in the same release that adds real checks.

---

## Unanimous top priorities (all four engines agreed)

### 1. Skill linter + trigger/routing evals, wired into CI  ⭐ #1 for all four
Portable, deterministic, free, engine-agnostic (it's just a script over markdown). This is the
foundational layer everything else rests on.

- **Structural lint (B Tier 1):** frontmatter present, `name` == directory, description carries
  a "what + when" sentence ≤1024 chars, required sections exist.
- **Routing evals (B Tier 2):** one JSON per skill with positive prompts (must rank the skill
  top-k) + negative prompts owned by a sibling skill (must NOT outrank it). Deterministic
  stemmed TF-IDF over descriptions — **not** embeddings (needless cost/nondeterminism at 11–15
  skills). Enforce a rank-1 floor (`--min-rank1 80`) and error at ≥75% description similarity.
- **Why it matters most for forge-ai specifically (kimi):** forge-ai routes **100% implicitly**
  (no slash syntax — the engine matches the task to a `description`). A description collision is
  a silent, per-user, ×3-engine failure. The real near-collision clusters to test:
  `quick-fix` vs `fix-bug` vs `new-feature`, and `review` vs `council`.
- **forge-ai-bespoke lint rules worth adding (kimi):**
  - *Index/catalog parity* — every `src/skills/*` appears in the CLAUDE.md skill index and vice
    versa (AGENTS.md is generated from it; one drift poisons all three engines).
  - *Reference integrity* — every `shared/rules/*` path a skill mentions actually exists.
  - *Model-ID quarantine* — grep skills for `gpt-`/`opus`/`glm`/`opencode-go/` and error;
    `models.md` is the declared single source, so a hard-coded ID is a lint failure.
- Require an eval file for every new skill (CI error otherwise, same as B).

### 2. Honest, tiered enforcement — portable script now, optional hooks later
The architectural key (kimi): **separate gate *policy* from gate *interception*.** Policy (what
must be true to ship) is already engine-neutral (`ship-gates.md` + `state.md`); only the
interception point is per-engine. The agreed tier model:

| Tier | Mechanism | Honestly guarantees |
| --- | --- | --- |
| **0 — Portable floor (default)** | advisory rules + native `ask` prompt | consistent instructions; a commit-confirmation (not a gate) |
| **1 — Assured, portable** | `check-gates.sh`/`.ps1` invoked by `finish-branch`; **CI + branch protection** | objective checks ran against the exact PR commit |
| **2 — Native hardening (opt-in, per engine)** | thin hook adapter behind `install --with-hooks`, calling the *same* script | local hard-blocking where an engine supports it |

- **Tier 1 is the honest upgrade and it's cheap.** `src/docs/extending.md` *already defines*
  this "Tier B" (skills + agent-invoked scripts) and nobody built it (kimi). A POSIX
  `check-gates.sh` (+ `.ps1` for parity) that parses `state.md`, knows the profiles, and exits
  non-zero listing unmet boxes converts "judge yourself" into "run this command" — far harder to
  rationalize past, and the same command a human or CI can run. The real gate for a team is the
  **PR + branch protection**, not the agent's machine (Codex).
- **Tier 2 keeps forge-ai's identity intact:** default install stays skills+config; the hook is
  a ~20-line adapter that maps the shared script's exit code to each engine's block signal;
  policy stays single-sourced. Start Claude-only (where A's proven implementation lives); add
  Codex/OpenCode adapters on demand. **Behind a flag, never default, clearly labeled
  "not cross-engine."**
- **Scope cut (kimi, strong):** block only `git push` / `gh pr create`, **never `git commit`** —
  commits are local and reversible; blocking them is the friction that gets enforcement
  uninstalled. (A blocks commits; forge-ai shouldn't.)
- **Don't chase what's genuinely impossible portably:** pre-compaction memory rescue, per-turn
  reminders, auto-format are out-of-turn events. `checkpoint` + the continuity golden rule is
  the portable substitute for memory; accept the loss on the rest.

### 3. Anti-rationalization + Red Flags + evidence-bound Verification, retrofitted to the 11 skills
In an advisory system, **the anti-rationalization table IS the enforcement** — it's the only
layer that stops the agent shortcutting TDD/review under time/sunk-cost/authority pressure, which
is exactly when gates matter (B's pressure-case evals exist because agents reliably skip steps
without explicit rebuttals). forge-ai's skills currently say *what* to do but not *what the agent
will tell itself to skip it*. Start with the four high-stakes skills (`new-feature`, `fix-bug`,
`finish-branch`, `review`). Bind "Verified" to a written line in `state.md`: command run +
observed output + HEAD sha. Costs almost nothing; makes the audit/waiver story real.

### 4. Convergence breaker as portable rule text
`review` today says "re-run until clean" — an unbounded loop a grinding model rides forever (A
built its convergence breaker for exactly this). A hard cap ("after N=3 non-clean iterations,
stop and escalate to human or `council`") is **pure skill text, fully portable, free.** Behavioral
evals can later verify the agent obeys it.

---

## Where the engines diverged (nuances worth noting)

- **Behavioral evals (B Tier 3):** all four say adopt a *minimal* version but **keep it out of
  the blocking CI path** (flaky, slow, needs three vendors' API keys). Divergence on scope:
  Codex says start with 4 workflow skills and grade *deterministic* outcomes first (files
  created, forbidden mutations absent) — "do not make an LLM judge the sole grader." glm/kimi say
  start with ONE skill + one pressure case, nightly, report-only, one runner, and be transparent
  it currently runs on one engine. Consensus: report-only, one runner, expand in Phase 3.
- **Review personas (B):** Codex and glm warn against an unconditional 4-reviewer fan-out on
  every change (latency, cost, contradictory noise). Preferred shape (kimi/Codex): a **risk-based
  lens** — extend `review` with an optional `security`/`tests`/`perf` parameter, triggered by
  change risk, not a new persona library.
- **Catalog additions — the ~14–15 target is unanimous, the exact list varies slightly:**
  - Everyone: **`adr`** (write an ADR — forge-ai scaffolds `docs/adr/` but has no skill that
    fills it; closes the repo-first memory loop).
  - Everyone: a **security** capability (as a `review` lens or a risk-triggered skill, not a
    domain library).
  - glm/kimi: **`tdd` as a callable skill** (it's only a rule today) and **`simplify`** (the
    refactor step is the first thing skipped under pressure).
  - Codex: **`migration`** as a first-class skill (compatibility/rollback/backfill — a real
    lifecycle gap `new-feature` doesn't cover).
  - Unanimous **rejects** (domain knowledge the base model already has → routing collisions +
    context weight, zero discipline gain): frontend-ui, api-design, performance, observability,
    ci-cd, browser-devtools, deprecation-as-standalone. Offer these later as optional *packs*
    (`forge-web`, `forge-platform`) using the same lint+eval contract — never in core.
- **`.forge-version` / drift:** all four want it; kimi notes forge-ai *already writes* a
  `.forge-manifest` (used by smoke.sh upgrade-prune), so a version stamp + drift warning is
  nearly free.

---

## Unanimous "do NOT" list

1. **Don't adopt A's hooks as default/required** — it silently re-breaks the portability the
   whole fork exists for. Opt-in overlay only.
2. **Don't build `/goal` autonomous mode yet** — autonomy without evidence gates is autonomous
   gate-skipping. A can run it safely because hooks guard it; forge-ai has neither today.
   Sequence it *after* the eval framework + gate script + convergence breaker land.
3. **Don't chase B's 24-skill catalog** — the moat is *process*, not domain content. Your own
   Tier-2 similarity metric will show the collisions.
4. **Don't call self-attested checkboxes "enforcement."** Tighten the README/`ship-gates.md`
   honesty language *now*, in the same release that adds real checks.
5. **Don't put behavioral evals in the blocking path**, don't block `git commit`, don't build
   runtime machinery (watchers/daemons — `state.md` + `CONTINUITY.md` is the right IPC), don't
   broaden past three engines yet, don't let model pins rot silently (add a "last verified" date
   to `models.md`), don't run unpinned `npx @latest` in CI, and don't let the linter/overlay
   grow its own gate logic and fork the policy.

---

## Suggested Phase 2 sequence (synthesized)

**v0.2.0 — Quality baseline**
1. CI (Linux/macOS/Windows, bash + PowerShell smoke) + generator golden/idempotency tests.
2. Skill linter (structural + forge-ai-bespoke rules) — blocking.
3. Tier-2 routing evals + one eval file per skill — blocking, `--min-rank1 80`.
4. Retrofit the 11 skills to the anatomy (Common Rationalizations / Red Flags / evidence-bound
   Verification); start with the four high-stakes skills.
5. Convergence-breaker rule text + evidence-binding fields in `state.template.md`.
6. `.forge-version` stamp + advisory drift warning. Tighten enforcement-honesty language.

**v0.3.0 — Assurance & selective growth**
7. Portable `check-gates.sh`/`.ps1` invoked by `finish-branch` + smoke fixtures (green passes,
   unchecked box fails, malformed profile fails).
8. Optional Tier-2 hook overlay behind `--with-hooks` (Claude first), single-sourced to the
   script. GitHub required-check + branch-protection guide.
9. New skills: `adr`, `simplify`/`tdd`, security lens on `review` (→ ~14 skills).
10. Minimal behavioral pressure suite (one runner, nightly, report-only).
11. Distribution: `npx forge-ai` wrapper over the existing installer; per-engine quickstart docs;
    a public demo repo showing a real `state.md` / council transcript / ADR / CHANGELOG. A
    generated (never hand-maintained) Claude marketplace entry.

**Defer to Phase 3:** `/goal` autonomous mode, full 3-engine behavioral matrix, Codex-style
Investigate (portable only as a sandboxed `research` variant), richer Council personas, Diátaxis
docs for forge-ai's own docs.

Guiding principle (Codex): **make the existing discipline measurable, make the guarantees honest,
then expand it.**

---

## Raw engine outputs

Full per-engine analyses are archived alongside this brief in
[`2026-07-18-phase-2-raw/`](2026-07-18-phase-2-raw/): `claude-opus-4.8.md`,
`codex-gpt-5.6-sol.md`, `opencode-glm-5.2.md`, `opencode-kimi-k3.md`, plus the identical
`briefing.md` handed to all four.
