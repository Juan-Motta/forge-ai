# Changelog

Notable changes, newest first. One short entry per shipped change. See
`shared/rules/docs-layout.md`.

## 2026-07-15

- Council logic review (4 advisors: Codex gpt-5.6-sol, Claude opus, 2× OpenCode glm-5.2) →
  NEEDS-WORK. Applied the cheap/factual fixes: three-engine consistency (OpenCode added to
  `ship-gates.md`, de-`(future)`'d the `workflow.md` table, OpenCode as driver in
  `state.template.md`) and honest enforcement wording (discipline not a hard gate; "should
  not" not "never override"; commit-confirmation not "backstop"; corrected the Codex
  `approval_policy` description). Substantive findings deferred to follow-up (see
  CONTINUITY.md): single-engine review path, per-workflow gate profiles, finish-branch
  ordering, read-only reviewer, installer config-propagation, Windows symlink note.
- Add `index` skill + `docs/index.md` — a high-level project map (structure, entry points,
  conventions) for fast agent orientation; refreshable, kept high-level to resist staleness.
- `install.sh` now refreshes framework `skills/` and `shared/rules/` **per entry (by
  name)** instead of wholesale replace — so a project's own skills/rules added to those
  dirs survive `--upgrade`.
- Fix `install.sh` skills-symlink handling: when a target already has a real
  `.claude/skills` (or `.codex`/`.opencode`) directory, warn and leave it instead of
  creating a broken nested `skills/skills` symlink; back up a real `AGENTS.md` too.
- Add `install.sh` — copy-based installer to deploy the discipline into a target project
  (managed baseline overwritten; project-owned files created-if-missing; existing CLAUDE.md
  backed up; `.gitignore` merged). Idempotent / `--upgrade`.
- Add project-specific rules layer: `PROJECT.md` (+ template) for persona / project info /
  variables / special rules, `shared/rules/project-rules.md` (precedence: adds to but never
  overrides the safety baseline), a golden rule to load it, and OpenCode `instructions`
  force-load.
- Repo hygiene + docs: add `.gitignore` (ignores `.workflow/`; durable handoff stays in
  committed `CONTINUITY.md`), `LICENSE` (MIT), document how to invoke a skill per engine in
  the README, and fix a stale "both engines" → "all engines" wording.
- Record ADR 001 (commit `CONTINUITY.md`) — decided via a live `council` run across all
  three engines (Codex + Claude + OpenCode); also validated `council` end-to-end.
- Set model defaults in `shared/rules/models.md`: Codex `gpt-5.6-sol` @ `xhigh`, Claude
  `opus` @ `high`, OpenCode `opencode-go/glm-5.2`.
- Add `shared/rules/models.md` — default model per cross-engine role (research/review/
  council; reviewer ≠ driver); wire `review`/`council`/`research`/`new-feature`/`fix-bug`
  to read from it.
- Add session continuity: `CONTINUITY.md` (+ template), `shared/rules/continuity.md`, the
  `checkpoint` skill, and a session-start "resume from continuity" golden rule.
- Add memory discipline (`shared/rules/memory.md`), docs layout
  (`shared/rules/docs-layout.md`), and the `prd` skill; scaffold `docs/` folders
  (prds, plans, research, solutions, adr) and this changelog.
- Add Tier-A skills: `research`, `plan`, `council`; rules: `tdd`, `research`,
  `approach-comparison`.
- Add OpenCode as a third interoperable engine.
- Initial skeleton: interoperable workflow discipline for Claude Code, Codex, OpenCode.
