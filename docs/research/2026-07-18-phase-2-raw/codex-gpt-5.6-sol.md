# Phase 2 recommendation

Phase 2 should be a **trustworthiness release, not a catalog-expansion release**. Forge-ai’s differentiator is a consistent workflow across engines. Because enforcement is mostly advisory, the quality, testability, and honesty of those instructions matter more than adding another dozen skills.

## The top 3 things I would do first

### 1. Build the skill quality harness and CI

This is the highest-leverage change. In an advisory framework, skills are effectively executable code; currently they have no linting, routing tests, behavioral tests, or CI.

Ship:

- A structural skill linter.
- One eval definition per skill.
- Deterministic trigger/routing tests.
- Generator parity and idempotency tests.
- Bash and PowerShell installer tests in CI.
- A rule that no skill change merges without its evals changing or explicitly remaining valid.

Initial CI targets:

- 100% of skills have valid eval files.
- 100% generated artifacts match the neutral source.
- 100% generator idempotency.
- At least 80% owned positive prompts rank their intended skill first, then ratchet toward 90%.
- 100% rank within the top three.
- Negative prompts route to the intended competing skill.
- Description similarity above 75% fails or requires an explicit exemption.

Run structural and routing tests on every PR. Run expensive behavioral tests nightly and before releases.

**Why first:** Adding skills before testing routing will make `plan`, `new-feature`, `quick-fix`, `fix-bug`, `review`, and `council` increasingly ambiguous.

---

### 2. Introduce an honest, optional “assured” enforcement tier

Hard enforcement is impossible under pure skills-and-config when the same agent can write both the work and the evidence. Forge-ai should state this explicitly.

Use three assurance levels:

| Tier | Mechanism | What it can honestly guarantee |
|---|---|---|
| Portable core | Skills and generated engine config | Consistent instructions and native approval prompts |
| Assured | CI checks plus protected branches | Objective checks ran against the exact PR commit |
| Native hardening | Optional engine-specific hooks/config | Additional local blocking where an engine supports it |

The portable core remains forge-ai’s default identity. The assured tier is engine-neutral because it runs outside the coding-agent turn.

The assured tier should verify:

- Generated files are synchronized with the pinned Forge version.
- Tests, lint, and configured verification commands pass at the PR HEAD.
- Required plan/review artifacts exist and match their schemas.
- Review evidence refers to the current code revision and is invalidated by later code changes.
- Driver and reviewer declare different engines.
- Required checks are protected by repository branch rules.

Use explicit terminology in reports:

- **Verified:** CI recomputed the fact.
- **Attested:** an agent or human claimed it, and Forge validated only its structure.
- **Advisory:** present only as an instruction.

Cross-engine review is merely attested unless the reviewer is launched by a trusted external service that produces a signed status. A JSON file saying `reviewer_engine: codex` is not proof that Codex performed the review.

This tier will require a small verifier outside the agent turn. That technically expands the “only installer and sync are executable” boundary, but it is the smallest defensible change if real enforcement is desired. Keep the verifier out of target repositories and invoke a pinned release or action from CI.

**Do not market attested process gates as hard enforcement.**

---

### 3. Refactor the existing 11 skills before adding more

Adopt a compact, mandatory skill anatomy:

1. Purpose and owned intent.
2. When to use.
3. When not to use, including the competing skill.
4. Preconditions and safety boundaries.
5. Process.
6. Required artifacts and exit evidence.
7. Failure, escalation, and maximum-loop behavior.
8. Common rationalizations.
9. Red flags.

Every skill should answer four operational questions:

- What causes this skill to own the request?
- What observable artifact does it produce?
- What evidence allows it to declare completion?
- When must it stop instead of continuing autonomously?

Keep each `SKILL.md` short. Move shared testing, security, evidence, and review material into progressively loaded references.

**Why third:** Pressure-resistant instructions will improve every engine immediately, while a larger catalog would increase context cost and routing collisions.

---

# Ranked additions from the reference projects

## P0 — Phase 2 foundations

### 1. B’s Tier 1 and Tier 2 eval framework

Adopt nearly wholesale at the conceptual level:

- Frontmatter and required-section validation.
- Link and reference validation.
- Stable skill naming.
- Positive and negative routing prompts.
- Collision detection.
- Eval coverage required for every skill.
- CI gating.

Implement the tooling inside the forge-ai development repo; do not copy it into target projects. A dependency-light Node implementation is reasonable if npm distribution is planned, but Node must remain a contributor/install convenience rather than a target-project runtime requirement.

### 2. A’s evidence binding, adapted to CI

Adopt the idea, not the hook implementation.

Objective evidence should be produced by CI and bound to the CI commit SHA. Avoid committed files that claim to describe the current `HEAD`: embedding the current commit SHA in a file that is itself committed creates awkward freshness problems.

Use:

- CI artifacts/status checks for volatile test and build evidence.
- Durable repo files for plans, ADRs, review summaries, and blockers.
- Review summaries that identify the revision reviewed.
- A rule that subsequent code changes invalidate the previous review.

A small evidence record might contain:

```text
gate_id
subject_sha
producer_type
producer_engine
status
artifact_reference
```

Raw transcripts should not be required: they create privacy, credential, and repository-bloat risks.

### 3. B’s pressure-case behavioral tests

Start with four skills:

- `new-feature`
- `fix-bug`
- `quick-fix`
- `finish-branch`

Test prompts that apply:

- Time pressure.
- Authority pressure.
- “This is too small for tests.”
- Sunk-cost pressure.
- Requests to skip cross-engine review.
- Requests to declare success from stale evidence.
- Requests to weaken tests to make them pass.

Grade deterministic outcomes first:

- Expected files created.
- Required sections present.
- Commands executed.
- Forbidden mutations absent.
- Completion withheld when evidence is missing.

Do not make an LLM judge the sole grader. Model grading is useful for nuance but introduces cost, drift, and false confidence.

Run one reference-engine behavioral suite on normal PRs if affordable; run all three engines nightly or at release time.

### 4. A’s convergence breaker

This is particularly valuable for an advisory system because agents otherwise tend to repeat review/fix cycles.

Define a clear limit, for example:

- At most two remediation rounds after the first cross-engine review.
- Immediate escalation if the same high-severity finding reappears.
- After the limit, write a blocker containing the disputed finding, attempted resolutions, current evidence, and available human choices.
- Do not silently downgrade severity or substitute same-engine approval.

This remains advisory in the portable tier, but pressure evals can verify that agents obey it.

### 5. A’s version pin and drift detection

Add:

- `.forge-version`
- A generated-file manifest with source version and hashes.
- `sync --check`
- Clear generated-file ownership headers.
- Detection of local modifications before overwrite.
- Release compatibility notes.

`sync --check` should distinguish:

- Forge is outdated.
- Generated files have drifted.
- A user has locally edited generated output.
- The neutral source and generated copies disagree.

This materially improves team adoption without adding agent-time runtime machinery.

## P1 — workflow strengthening

### 6. Repo-first continuity hardening

Do not try to emulate `pre-compact-memory` without hooks. Instead, make checkpoints predictable:

- Update `CONTINUITY.md` at phase boundaries.
- Update before cross-engine handoff.
- Update after a material decision or failed approach.
- Update before intentionally ending a long session.

Use a bounded format:

```text
Current phase and revision
Goal and acceptance criteria
Completed work with evidence
Decisions and ADR links
Open risks and blockers
Next three actions
```

Keep it as a replaceable current-state summary, not an unbounded diary. Explicitly prohibit secrets, credentials, production payloads, and sensitive incident data.

Add a behavioral eval in which a fresh agent receives only the repository and `CONTINUITY.md`; it should recover the correct phase and next action.

### 7. Risk-based specialist review

Adopt B’s specialist personas selectively, not as an unconditional four-reviewer fan-out.

Use a change-risk classifier in `plan` or `review`:

- Authentication, authorization, secrets, or trust boundaries → security review.
- Public API or data-contract changes → interface/compatibility review.
- User-facing web changes → browser/accessibility review.
- Hot paths or explicit latency goals → performance review.
- Schema or deployment changes → migration/rollback review.

Always running four reviewers would add latency, cost, and contradictory noise to ordinary changes.

### 8. Council minority reports

Keep the existing council, but borrow two features from A:

- Independent opinions before synthesis.
- A required minority or strongest-counterargument section.

Do not import a fixed six-agent council. A small council of two independent advisors plus a synthesizer is enough for most decisions. Reserve a larger council for irreversible architecture, security, migration, and incident decisions.

## P2 — experiments, not defaults

### 9. Investigate mode

A portable `investigate` skill could be useful, but it should be experimental and off by default.

Require:

- Explicit scope and allowed systems.
- Read-only commands.
- No credential printing.
- Data minimization and redaction.
- Reproduction evidence.
- Cross-verification of consequential findings.
- Immediate stop when read-only status is uncertain.

Without hooks or a trusted sandbox, Forge cannot guarantee that an investigation stays read-only. The documentation must not imply otherwise.

### 10. Autonomous goal mode

Defer this until the eval framework, continuity behavior, convergence breaker, and assured gate tier are stable.

A `/goal`-style skill without trusted state is mostly a very long orchestration prompt. It will amplify skipped gates, stale evidence, and compaction failures.

If introduced later:

- Make it experimental.
- Preserve PR creation as a human gate.
- Cap retries and review cycles.
- Stop on ambiguity rather than inventing product decisions.
- Persist every phase transition.
- Never treat absence of user response as approval for an external mutation.

# Skill catalog: what to add and what to fold in

Forge-ai should not try to match B’s 24 skills. Its purpose is workflow discipline, not a universal software-engineering encyclopedia.

## Add as first-class skills

### `migration`

This fills a real lifecycle gap not adequately represented by `new-feature`.

It should cover:

- Compatibility contracts.
- Data/schema migration.
- Dual-read or dual-write periods.
- Rollback and roll-forward plans.
- Deprecation windows.
- Backfill verification.
- Mixed-version deployments.
- Irreversible-step approval.

### `security-review`

Make this risk-triggered, not mandatory for every change.

It should own explicit security assessment requests and high-risk changes involving:

- Authentication and authorization.
- Secrets.
- Untrusted input.
- Cryptography.
- File/process execution.
- Network boundaries.
- Sensitive data.

Keep implementation guidance in shared references so the main skill stays compact.

## Strengthen existing skills instead of adding competitors

| B capability | Forge recommendation |
|---|---|
| Interview-me / idea-refine | Add optional discovery questions to `prd` |
| Spec-driven development | Already covered by `prd` → `plan` → `new-feature` |
| Planning/task breakdown | Strengthen `plan` |
| Incremental implementation | Make it an invariant of `new-feature` and `fix-bug` |
| Test-driven development | Keep as shared rule enforced by relevant workflows |
| Source-driven development | Strengthen `research` with source hierarchy and claim tracking |
| Doubt-driven development | Add counter-evidence and uncertainty sections to `research` and `plan` |
| Debugging/error recovery | Strengthen `fix-bug`; avoid a colliding `debug` skill initially |
| Code simplification | Add a mandatory simplification pass to `review` |
| API/interface design | Add a risk-triggered plan checklist before considering a separate skill |
| Documentation/ADRs | Add ADR thresholds to `plan` and `finish-branch` |
| Git/versioning | Already owned by `checkpoint` and `finish-branch` |
| Shipping/launch | Extend `finish-branch`; do not duplicate it |
| Using-agent-skills | Improve `index` into the explicit meta-router |

The strengthened `fix-bug` process should require:

- Reproduction before modification.
- Ranked hypotheses.
- A regression test that fails for the right reason.
- Minimal causal fix.
- Recovery when the hypothesis is disproven.
- Stop conditions after repeated failed approaches.

## Keep out of the core catalog

These are useful, but domain-specific rather than central to Forge’s workflow discipline:

- Frontend UI engineering.
- Browser DevTools testing.
- Performance optimization.
- Observability implementation.
- CI/CD implementation.
- Accessibility engineering.
- Framework-specific testing guidance.

Offer them later as optional packs such as `forge-web`, `forge-platform`, or `forge-security`. Packs must use the same linter and eval contract as core skills.

“Context engineering” should remain an internal design principle, not a user-facing workflow skill.

# Portable enforcement: the hard boundary

There is no configuration-only trick that provides trustworthy process enforcement. A hard gate requires a trusted observer that the agent cannot freely rewrite.

That observer must be one of:

- CI plus branch protection.
- A source-control server bot.
- A local hook.
- An agent wrapper/orchestrator.
- A human approval.

Therefore:

1. Preserve skills-only behavior as the universal baseline.
2. Add CI enforcement as the recommended portable assurance layer.
3. Keep native hooks experimental and strictly additive.
4. Document which guarantees disappear when branch protection is not enabled.

If native adapters are eventually added, generate them from one neutral gate specification. They may tighten enforcement but must not change workflow semantics. Add conformance tests so, for example, “verified,” “reviewed,” and “waived” retain the same meaning across adapters.

Do not add Claude hooks first and promise that other engines are “equivalent.” That would create a Claude product with compatibility exports, not a cross-engine framework.

# Distribution and adoption

## First: make upgrades safe

Before marketplaces, add:

- Exact version pinning.
- Generated artifact manifests.
- Drift checking.
- Upgrade and rollback documentation.
- A compatibility matrix covering tested versions of Claude Code, Codex, and OpenCode.
- A `validated_on` field for pinned model defaults.
- A documented override mechanism when a model is unavailable.

Model names should remain centralized, but workflow logic must not depend on one exact model identifier. “Different engine” is a process-diversity rule, not proof of independent correctness.

## Second: add an optional npx entry point

A good surface would be:

```text
npx @forge-ai/cli@0.2.0 install
npx @forge-ai/cli@0.2.0 sync
npx @forge-ai/cli@0.2.0 sync --check
```

Requirements:

- Pin versions in examples; never recommend `@latest` in CI.
- Do not add a runtime dependency to target repositories.
- Keep Bash and PowerShell entry points supported.
- Have the package consume the same neutral source and generator.
- Publish checksums or provenance for release artifacts.

The npx interface is a distribution wrapper, not a second implementation.

## Third: publish generated marketplace packages

A Claude plugin or marketplace listing is useful for discovery, but it must be generated from `src/`, never maintained independently.

Treat every tool-specific package as an adapter:

```text
neutral source → generator → Claude package
                           → Codex package
                           → OpenCode package
```

The release should fail if normalized policy content differs unexpectedly between adapters.

## Per-tool documentation

Each engine needs a short, tested guide containing:

- Five-minute installation.
- Exactly which files are generated.
- How skill routing works.
- How to invoke a cross-engine reviewer.
- Approval and permission behavior.
- Upgrade and drift workflow.
- Uninstall procedure.
- Known capability differences.

Focus on the three supported engines. Advertising support for dozens of agents would dilute Forge’s strongest claim before it is thoroughly tested.

# What not to do

- **Do not clone all 24 skills.** It will create routing ambiguity and load irrelevant guidance.
- **Do not add autonomous goal mode before evals and stop conditions.** Autonomy magnifies weak discipline.
- **Do not call checkboxes enforcement.** Agent-authored state is an attestation.
- **Do not make Claude hooks the canonical implementation.** Optional hardening is acceptable; Claude-first semantics are not.
- **Do not require large councils or four specialist reviews for every change.** Use risk-based escalation.
- **Do not let generated engine files become separately editable sources.**
- **Do not impose Diátaxis on every target repository.** Use it for Forge’s own documentation and offer target guidance.
- **Do not turn `CONTINUITY.md` into an append-only transcript.**
- **Do not install a daemon, background state machine, or agent wrapper.** That would change Forge from a portable discipline into an orchestration runtime.
- **Do not execute unpinned remote actions or `npx latest` in CI.**
- **Do not copy code or wording from the reference projects without checking licenses and attribution requirements.**
- **Do not broaden engine support during Phase 2.** Prove the three-engine promise first.

# Suggested Phase 2 release sequence

## v0.2.0 — Quality baseline

- CI on Linux, macOS, and Windows.
- Bash and PowerShell smoke coverage.
- Generator golden tests and idempotency.
- Structural skill linter.
- Eval file for all 11 skills.
- Deterministic routing tests.
- Refactored skill anatomy.
- `.forge-version` and drift detection.

## v0.3.0 — Assurance

- Evidence schema.
- Optional pinned CI verifier.
- GitHub required-check template and branch-protection guide.
- Verified/attested/advisory terminology.
- Review freshness checks.
- Convergence breaker.
- Behavioral pressure suite across the critical workflows.

GitHub can be the first source-host adapter without claiming source-host neutrality. Keep the verifier protocol independent enough for GitLab or other CI adapters later.

## v0.4.0 — Selective expansion

- `migration`.
- Risk-triggered `security-review`.
- Specialist review profiles.
- Generated marketplace packages.
- Optional npx installer.
- Experimental `investigate`, only if its safety evals are convincing.

The guiding principle should be: **make the existing discipline measurable, make the guarantees honest, then expand it.**