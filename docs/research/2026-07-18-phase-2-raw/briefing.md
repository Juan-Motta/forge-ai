# Research briefing — how to improve forge-ai (Phase 2)

You are an expert advisor on AI-coding-agent frameworks. Analyze the material below and
produce concrete, prioritized recommendations to improve **forge-ai**. Be specific and
opinionated. Do NOT just summarize — propose changes, name trade-offs, and flag risks.

## 1. What forge-ai IS (the project to improve)

forge-ai is a framework repo that installs ONE consistent AI-coding workflow discipline
(research → plan → TDD → cross-engine review → verify → ship) into a target project, so the
same rules/skills/guardrails run identically on **Claude Code, Codex, and OpenCode**.

Deliberate design choices (these are its identity — challenge them only with strong reason):
- **Skills + config ONLY. No runtime hooks.** The only scripts are the installer and a `sync`
  generator, both run OUTSIDE the agent's turn. Enforcement is *advisory* (skills instruct the
  agent to pass gates) + each engine's *native* approval prompt on push/PR (bypassable, reads
  no gate state).
- **Neutral source + generator (no symlinks).** One engine-neutral source in `src/` (CLAUDE.md,
  skills/, shared/rules/, configs/). A generator copies per-engine artifacts (AGENTS.md,
  .claude/, .agents/, .codex/, opencode.json) into the target by plain copy. Cross-platform
  (bash + PowerShell).
- **Thin install.** Target gets only runtime files; all machinery stays in forge-ai.
- Just shipped **v0.1.0** (first stable), verified on all three engines.

Current inventory:
- **11 skills:** prd, research, plan, new-feature, fix-bug, quick-fix, review, council,
  finish-branch, checkpoint, index.
- **11 rules:** approach-comparison, continuity, docs-layout, memory, models, project-rules,
  research, severity, ship-gates, tdd, workflow.
- **Memory model (repo-first):** durable knowledge in the repo (docs/solutions, docs/adr,
  docs/CHANGELOG) because all engines read it; CONTINUITY.md for session handoff.
- **Cross-engine roles:** reviewer/advisor always runs on a DIFFERENT engine than the driver
  (model diversity). Models pinned in one file (models.md): Codex gpt-5.6-sol, Claude opus,
  OpenCode opencode-go/glm-5.2.
- **Tests:** only `tests/smoke.sh` (installer smoke). No CI. No skill evals. No skill linting.

## 2. Reference project A — pablomarin/claude-codex-forge (the rich ancestor)

A far more mature sibling (v5.56). forge-ai is essentially a simplified, portable fork of it.
Key things it HAS that forge-ai dropped or lacks:
- **Full hooks enforcement layer** (Claude Code hooks): `check-workflow-gates` literally BLOCKS
  git commit/push/PR until state.md shows Code-review/Simplified/Verified markers;
  `check-bash-safety` blocks dangerous Bash (pipe-to-shell, reverse shells, cred exfil);
  `check-state-updated`, `build-evidence`, `pre-compact-memory` (rescues learnings before
  compaction), `post-tool-format`, `session-start`, `ConfigChange` audit.
- **Autonomous goal mode (`/goal`)**: after an approved PRD, one command drives the whole
  lifecycle plan→review→implement→review→verify→E2E→PR autonomously; escalates hard calls to
  the Council; the ONE hard human gate is PR creation; halts + writes a blocker if stuck.
- **Codex Investigate mode**: gives Codex real sandboxed hands on live systems (query a DB, hit
  a cloud API, reproduce a bug) — repo-confined, read-only, cross-verified.
- **Engineering Council**: 5 advisors (3 Claude + 2 Codex personas + Codex chairman), anonymous
  peer review, mandatory minority reports.
- **Evidence-based gates**: E2E checkbox bound to a real report artifact; per-iteration clean
  evidence lines (plan_sha / HEAD binding); a **convergence breaker** that hard-stops a
  review loop that grinds past certification until a HUMAN adjudicates.
- **ADRs** (docs/adr, append-only) + **Diátaxis docs** (explanation/guides/reference/tutorial).
- **Team-scale**: git worktrees for parallel sessions; committed `.claude/` as team standard +
  a `.forge-version` pin with advisory drift warnings.
- Its philosophy: "a template is files you copy once; a harness runs continuously around your
  work." Discipline is *guarded by hooks*, not just guided.
- TENSION: forge-ai deliberately chose NO hooks for cross-engine portability (hooks are
  Claude-Code-specific). So adopting A's enforcement wholesale would break the portability that
  is forge-ai's whole point. The interesting question is what enforcement is achievable
  portably, or per-engine as an optional tier.

## 3. Reference project B — addyosmani/agent-skills (79k stars, mature skill library)

The most-adopted engineering-skills library. Key things forge-ai can learn from:
- **24 lifecycle skills** (vs forge-ai's 11), spanning Define→Ship: interview-me, idea-refine,
  spec-driven-development, planning-and-task-breakdown, incremental-implementation,
  context-engineering, source-driven-development, doubt-driven-development,
  frontend-ui-engineering, api-and-interface-design, test-driven-development,
  browser-testing-with-devtools, debugging-and-error-recovery, code-review-and-quality,
  code-simplification, security-and-hardening, performance-optimization,
  git-workflow-and-versioning, ci-cd-and-automation, deprecation-and-migration,
  documentation-and-adrs, observability-and-instrumentation, shipping-and-launch,
  using-agent-skills (meta-router).
- **A three-tier EVAL FRAMEWORK in-repo (their crown jewel):**
  - Tier 1 Structural: frontmatter/naming/required-sections/command-parity lint (CI, free).
  - Tier 2 Trigger & routing: each skill's positive prompts must rank the skill top-k; negative
    prompts (owned by another skill) must NOT outrank it; no two descriptions near-collide
    (≥75% similarity = error). Deterministic stemmed TF-IDF over descriptions, CI, free. Prints
    a "trigger rank-1 rate" metric; CI enforces a floor (--min-rank1 80).
  - Tier 3 Behavioral: runs each skill's eval through headless `claude -p` in a throwaway git
    repo with real fixtures, grades the full execution trace against per-skill `expectations[]`.
    Includes **pressure cases** (time pressure, sunk cost, authority pressure) that verify the
    workflow HOLDS when the prompt argues to skip it.
  - Eval case format: one JSON per skill with trigger.positive/negative + evals[] with
    prompt/expected_output/files/expectations. Every new skill MUST ship an eval file (CI error
    otherwise).
- **Skill linter** (validate-skills.js + skill-lint.js): a single-source-of-truth linter that
  checks every skill against the anatomy spec; exit 1 on error. Runs in CI.
- **Skill anatomy discipline:** every skill = frontmatter (name + "what + when" description,
  ≤1024 chars) + Overview + When to Use + Process + **Common Rationalizations table** (excuses
  agents use to skip steps, each rebutted) + **Red Flags** + **Verification** (evidence
  requirements). "Process, not prose." Progressive disclosure (SKILL.md < 500 lines; supporting
  files load on demand; prefer scripts over inline code to save context).
- **Review personas** fanned out in parallel at ship time (code-reviewer, security-auditor,
  test-engineer, web-performance-auditor) → merged into go/no-go.
- **Shared reference checklists** used across skills (definition-of-done, testing-patterns,
  security, performance, accessibility, observability, orchestration-patterns).
- **Distribution:** Claude Code plugin/marketplace + `npx skills add` CLI installing into 70+
  agents; per-tool setup docs (Cursor, Gemini, Copilot, Windsurf, OpenCode, Codex, Kiro, etc.).
- Honest self-assessment: none of the three big skill libs (agent-skills, Superpowers, Pocock)
  has solved durable cross-session memory well yet.

## 4. Your task

Given forge-ai's identity (portable, cross-engine, skills+config, no hooks, thin install),
recommend how to improve it in Phase 2. Address at least:
1. **Highest-leverage additions** — what to adopt from A and B, ranked, with WHY.
2. **The enforcement tension** — how (if at all) forge-ai can get real gate enforcement without
   breaking cross-engine portability. Portable options? Optional per-engine tier?
3. **Quality of the skills themselves** — should forge-ai adopt an eval framework + skill
   linter + anti-rationalization/red-flags anatomy? What's the minimal version worth doing?
4. **Skill catalog gaps** — which of B's 24 skills fill real gaps for forge-ai's users; which
   are out of scope for its philosophy.
5. **Distribution & adoption** — plugin/marketplace, npx-style install, per-tool docs.
6. **What NOT to do** — traps, over-engineering, things that would betray forge-ai's identity.

Output a prioritized, sectioned analysis. Concrete over abstract. Name the top 3 things you'd
do first and why.
