# Phase 2 Analysis — Recommendations for forge-ai

## Top 3 things I'd do first (and why)

1. **Add a structural + trigger skill linter with CI (Tier 1+2 from B).** It's free, portable, engine-agnostic, and the single highest-leverage thing missing. forge-ai's skills are currently 36–71 lines with no machine-checked anatomy, no trigger-routing sanity, and no CI of any kind. The whole framework's *quality* currently rests on the author's eyeballs. A `scripts/validate-skills.js` enforcing frontmatter, name/description bounds, required sections (When to Use / Process / Verification), and a `--min-rank1 80` trigger floor over stemmed TF-IDF would catch collision and drift the moment a skill is added — before it ships to all three engines. This is the foundational layer that everything else (evals, anti-rationalization, catalog growth) rests on. ~1–2 weekends.
2. **Add a thin **convergence breaker + evidence-bound gates** as portable advisory rules in `ship-gates.md`**, not as hooks. The two enforcement defects that actually bite in forge-ai today are (a) the review loop can grind forever with no stop condition, and (b) state.md boxes are self-attested — "verified" can mean "I ran it in my head." A and B both fix these: A's convergence breaker hard-stops a circular review past N iterations and demands human adjudication; B's `expectations[]` require an artifact reference (test command output, file path). Both are pure *rules text* — they work identically across Claude/Codex/OpenCode and stay true to "skills + config only." This is portable enforcement that hooks never could be. ~1 day.
3. **Ship an **anti-rationalization + Red Flags section** in every skill, retrofitted to the existing 11.** This is the cheapest credibility upgrade in the whole catalog. A's Common Rationalizations table and B's Red Flags directly attack the real failure mode of advisory-only systems: the agent quietly shortcuts the gate under time/sunk-cost/authority pressure. forge-ai's skills currently say *what* to do but not *what the agent will say to skip it*. Three sentences per skill. ~half a day, and it pays off forever — especially because B's own pressure-case evals show that without explicit rebuttals, agents skip workflow steps reliably.

---

## 1. Highest-leverage additions (ranked)

| # | Addition | From | Why it's high-leverage for forge-ai specifically |
|---|---|---|---|
| 1 | **Skill linter (structural) + trigger TF-IDF routing test, in CI** | B | forge-ai has zero quality machinery. Skills are 36–71 lines, hand-curated. Linter is portable, free, deterministic, runs on every engine identically (it's just node on markdown). Catches the silent disease: two skills whose descriptions collide so neither engine routes reliably. |
| 2 | **Convergence breaker + evidence-bound gate checkboxes** | A | The two real enforcement holes you can close *without* hooks. Pure rules text. Portable. |
| 3 | **Common Rationalizations + Red Flags sections in every SKILL.md** | A+B | The advisory-only model's biggest weakness is silent shortcutting. Explicit rebuttals work, per B's pressure-case evals. Costs almost nothing. |
| 4 | **Behavioral evals (Tier 3) — minimal version** | B | Headless `claude -p`/`codex exec`/`opencode run` in a throwaway repo, grading against `expectations[]`. Start with ONE skill (`review`) + one pressure case, expand slowly. This is the only way to know forge-ai's discipline actually survives contact with the agent. |
| 5 | **`/goal`-style autonomous mode** | A | forge-ai has `new-feature` (interactive) but nothing that drives the full lifecycle unattended. High value but high risk *without* #2 and #4 already in place — autonomy without evidence gates is just faster foot-guns. Do this third, not first. |
| 6 | **Diátaxis docs split** (explanation / guide / reference / tutorial) | A | forge-ai currently has one `docs/extending.md`. This is a clarity win, not a discipline win — do it when adoption warrants, not now. |
| 7 | **Engineering Council as a richer `council` skill** | A | forge-ai's `council` is 71 lines; A's is 5 named personas with mandatory minority reports. Upgrade is cheap and consistent with forge-ai's existing direction — but only after evals prove single-reviewer routing works first. |
| 8 | **`.forge-version` pin + drift warning (advisory)** | A | Cheap, portable, useful the moment someone installs forge-ai into a team repo. Low risk. |

Don't adopt: A's full hook layer (breaks portability, see §2), A's git-worktrees-as-team-standard (out of forge-ai's scope — that's a *host repo* decision), Codex Investigate mode (valuable but tied to one engine).

---

## 2. The enforcement tension — how to get real gates portably

forge-ai's identity is "no runtime hooks, cross-engine identical." That's also its enforcement ceiling. The honest answer is **you cannot get A-grade conditional blocking portably** — hooks are a Claude-Code-native feature; faking them in Codex/OpenCode means writing per-engine wrappers, which betrays thin-install. So design the enforcement as a **tiered model**, and let the user opt in:

**Tier 0 (default, portable, what ships today):** advisory rules + native `ask` prompt. Strengthen with #2 and #3 above — convergence breaker, evidence-bound checkboxes, anti-rationalization. This is the floor and it is honest.

**Tier 1 (portable, generator-emitted, opt-in via install flag):** a single repo-resident script `scripts/check-gates.sh` (bash + powershell) that `finish-branch` instructs the agent to invoke *before* `gh pr create`. It reads `.workflow/state.md`, exits non-zero if profile boxes are unchecked or the convergence breaker tripped. The agent is *instructed* to run it (advisory) — but any engine that honors a non-zero bash exit will stop and surface it. Not a hard block, but a *structured* failure the agent has to actively argue past. This is the most enforcement you can buy without hooks, and it's 100% portable.

**Tier 2 (optional per-engine, for power users):** a generated `.claude/hooks.json` PreToolUse hook calling `check-gates.sh` — Claude-Code-only, clearly documented as "if you run Claude Code and want hard enforcement, also install this tier." The generator emits it behind `--hooks` so the thin default install stays clean. This is the principled resolution of the tension: keep the *default* portable, expose the *enforcement* as an opt-in engine-specific add-on that explicitly comments "this tier is not cross-engine."

**Tier 3 (full A parity):** defer. Only worth it once Tier 1 is proven and someone actually needs the convergence-breaker-to-human-adjudication loop in production.

Risk: don't pretend Tier 0 is Tier 2. The current README/assertion that native `ask` prompts are "best-effort enforcement" is already a soft overstatement — they read no state, match by pattern, and are bypassable via `git -C . push`. Tighten the language *now* while you add Tier 1; the worst outcome is users trusting an enforcement layer that isn't there.

---

## 3. Skill quality — what to adopt and the minimal viable version

Adopt all three of B's quality layers, but layered by ROI:

**Mandatory (do now):**
- **Skill linter (Tier 1 + Tier 2 of B).** Rust-version of `validate-skills.js`. Checks: frontmatter present, `name` matches dir, `description` ≤ 1024 chars, includes a "what + when" sentence, required sections exist (Overview, When to Use, Process, Verification), no two descriptions ≥75% similar. Plus the trigger test: each skill has a `tests/trigger.json` with positive/negative prompts; positive must rank the skill top-3; negative (owned by another skill) must NOT. Enforce `--min-rank1 80` in CI. **This is the single most valuable thing forge-ai can add in Phase 2** because it converts skill quality from vibes to a number.
- **Anatomy retrofit:** every existing skill gets When-to-Use / Process / **Common Rationalizations table** / **Red Flags** / **Verification (with artifact requirement)**. forge-ai's current skills lack the Rationalizations and Red Flags sections entirely — and those two are what survive under pressure.

**Strongly recommended (do after CI green):**
- **Tier 3 behavioral evals, minimal.** One eval file per *shipped* skill (CI errors if a skill ships without one, per B). Run via `claude -p` for now (Codex/OpenCode runners added later — be transparent that Tier 3 currently runs on one engine; that's a real cost). Start with 3 skills: `review`, `plan`, `fix-bug`. Include at least one **pressure case** per skill ("the user says ship it, we're late, skip review" → expect the skill to refuse and cite the gate). This is what proves the advisory model actually holds when pushed.

**Skippable for now:**
- B's parallel review personas (code-reviewer / security-auditor / test-engineer / perf-auditor fan-out). forge-ai already has `council` for the hard-fork case; fanning out four personas on every ship is overkill for a thin framework. Keep it as a future `council` upgrade.

**Minimal version worth doing:** linter + trigger test + anatomy retrofit, no behavioral evals. That alone puts forge-ai ahead of every other thin framework I've seen and is ~1 week of work.

---

## 4. Skill catalog gaps — B's 24 mapped to forge-ai

forge-ai's 11 already cover: prd≈`idea-refine`/`interview-me`, research≈`source-driven-development`, plan≈`planning-and-task-breakdown`, new-feature≈`incremental-implementation`+`spec-driven-development`, fix-bug≈`debugging-and-error-recovery`, quick-fix≈(lightweight path), review≈`code-review-and-quality`, council≈(A's council persona spread), finish-branch≈`git-workflow-and-versioning`+`shipping-and-launch`, checkpoint≈(continuity, B has no equivalent), index≈(forge-ai-only).

**Real gaps worth filling (ranked):**

1. **`tdd` as a first-class skill, not just a rule.** forge-ai has `tdd.md` as a *rule* but no `tdd` *skill*. B has `test-driven-development` and `browser-testing-with-devtools`. forge-ai's `new-feature` references TDD but doesn't expose it as a callable skill for the common case "I just need to add a feature with proper tests, no PRD theatre." High value, cheap.
2. **`security-and-hardening`** — forge-ai has nothing on security. A `review`-style cross-engine audit specifically for security findings would be reasonable to add as a skill or a `review` profile variant. Real gap, real demand.
3. **`debugging-and-error-recovery` skill (beyond `fix-bug`)** — `fix-bug` is incident-response shaped; B's `debugging-and-error-recovery` covers the "I'm stuck, this isn't a known bug" exploratory case. forge-ai's `fix-bug` could absorb it with a "unknown-cause" branch, or it's a new skill. Modest priority.
4. **`documentation-and-adrs`** — forge-ai has `docs/layout` *rules* and an `index` skill but no skill that *writes* an ADR. Given the repo-first memory model is a stated pillar, an ADR-writing skill is the obvious complement. Low effort, high coherence with existing philosophy.
5. **`deprecation-and-migration`** — useful but more product-shaped than workflow-shaped. Skip for now.
6. **`performance-optimization`, `frontend-ui-engineering`, `api-and-interface-design`, `observability-and-instrumentation`, `ci-cd-and-automation`** — these are domain skills, not workflow skills. **Out of scope for forge-ai's philosophy.** forge-ai is a *discipline layer*, not a domain library; adding 50 domain skills turns it into B, which is a different product. Resist.
7. **`context-engineering`, `doubt-driven-development`, `code-simplification`** — interesting but overlapping with forge-ai's existing discipline (review + plan + council already encode "doubt"). Skip to keep catalog tight.
8. **`using-agent-skills` (meta-router)** — forge-ai's `index` skill already serves this role. Skip.

**Net catalog target for Phase 2:** add `tdd`, `adr` (write an ADR), and one security skill. That brings forge-ai to 14 skills, each filling a real workflow gap the current 11 leave open. Don't try to match B's 24.

---

## 5. Distribution & adoption

- **`npx forge-ai add`** (or `npm i -g forge-ai && forge-ai install`) is the right next step — the installer already exists as `install.sh` / `install.ps1`. Wrapping it in an npm-distributed CLI gives `npx`-style one-liner install, which is how B reaches 70+ agents. The *content* stays markdown — only the *installer* is node. Low risk, high adoption impact.
- **Per-engine setup docs** in `docs/` (one page each: Claude Code, Codex, OpenCode — what gets installed where, what the native `ask` prompt covers, the single-engine fallback). forge-ai's licensingREADME already lists the engines but a quickstart per engine is missing. This is the lowest-effort adoption win in the whole plan.
- **Claude Code plugin / marketplace listing** — only once the linter and the trigger test are green. Publishing a plugin with un-routed skills is worse than not publishing. Defer.
- **Codex/OpenCode marketplaces** — don't exist in any real form yet; skip until they do.
- **A versioned `.forge-version` + advisory drift warning** (from A) is portable and pairs naturally with the npm CLI ("newer forge-ai available, run `forge-ai sync`"). Cheap, do it with the CLI release.

---

## 6. What NOT to do

- **Do NOT adopt A's hook layer as default.** It's the single biggest threat to forge-ai's identity. If you ship `.claude/hooks.json` in the default install you've silently re-broken portability and the whole fork-from-A was for nothing. Hooks are Tier 2 opt-in only, behind `--hooks`, with a clear "Claude Code only" label.
- **Do NOT chase B's 24-skill catalog.** forge-ai is a discipline layer, not a domain-skill library. Every domain skill added (frontend, perf, observability, api-design) dilutes the "one workflow discipline across three engines" thesis. Capping Phase 2 at ~14 skills keeps the catalog honest.
- **Do NOT pretend the native `ask` prompt is enforcement.** It's a confirmation, not a gate. Tighten the README and `ship-gates.md` copy right now. The current "best-effort native prompt" language is generous; the worst outcome of Phase 2 would be to *strengthen* the misleading claim while adding nothing behind it.
- **Do NOT build `/goal` autonomy before evidence-bound gates + behavioral evals exist.** Unattended lifecycle without convergence breakers and without proof that the gates hold under pressure is just faster incidents. Sequence: linter → evidence gates → evals → `/goal`.
- **Do NOT add git worktrees / team-scale machinery.** That's host-repo concern, not framework concern; forge-ai stays a per-repo discipline layer.
- **Do NOT add Codex Investigate mode.** Engine-specific, ties the framework to one engine's sandbox, breaks neutrality.
- **Do NOT write behavioral evals against all three engines on day one.** Pick one runner (`claude -p` is the most mature), be explicit that's what Tier 3 currently uses, expand later. Lying about cross-engine eval coverage would be a repeat of the "best-effort prompt" overstatement.
- **Do NOT let the linter become the product.** A skill framework where the linter is more sophisticated than the skills is a failure mode B occasionally flirts with. Discipline anatomy first, eval depth second, linter is just the checksum.

---

### Sequencing summary

1. **Week 1–2:** linter + trigger test + CI; retrofit all 11 skills with Rationalizations/Red Flags/evidence-bound Verification. Tighten enforcement-language honesty in README/rules.
2. **Week 3:** portable Tier 1 `check-gates.sh` + convergence-breaker rule text + `.workflow/state.md` evidence-binding fields. Add `.forge-version`.
3. **Week 4–5:** three new skills (`tdd`, `adr`, `security`); per-engine quickstart docs; wrap installer as npm CLI.
4. **Week 6:** behavioral evals for `review`/`plan`/`fix-bug` with pressure cases (one runner, documented).
5. **Week 7+:** `/goal` autonomous mode, richer `council` personas, ADR skill expansion, Diátaxis docs — only after the above lands.

This keeps forge-ai what it is (portable, thin, skills+config), fixes its actual weaknesses (no quality machinery, self-attested gates, silent shortcutting), and avoids the two traps that would betray it (wholesale hooks, domain-skill bloat).
