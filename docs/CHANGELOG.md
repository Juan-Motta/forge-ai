# Changelog — forge-ai (framework)

Notable changes to the forge-ai framework itself, newest first. This is the framework's own
development log; it is **not** the seed shipped to installed projects (that lives at
`src/docs/CHANGELOG.md`).

## Unreleased

- **Phase 2 — skill quality machinery (priority #1): linter + routing evals + CI.** New
  dependency-free Node tooling under `tools/` (dev-only — never shipped into a target). A
  **structural + forge-ai-bespoke skill linter** (`lint-skills.mjs`) enforces frontmatter,
  `name`==dir, description ≤1024 with a "Use when" trigger, CLAUDE.md index parity (both ways),
  **model-id quarantine** (`models.md` is the single source), and `shared/` reference integrity;
  missing `## Verification`/>500 lines are warnings. **Routing/collision evals** (`run-evals.mjs`,
  stemmed TF-IDF over descriptions, engine-name boilerplate stripped) catch missing-vocabulary
  and near-collision trigger bugs — real catalog scores rank-1 91%, 0 collisions. The eval
  surfaced and fixed two defects: a stemmer double-consonant bug (`shipping`→`ship`) and a `prd`
  description missing "spec / what to build / who it's for" vocabulary. New `.github/workflows/ci.yml`
  runs lint → evals → 20 unit tests → installer smoke on every push/PR. Basis: the multi-engine
  Phase-2 research brief in `docs/research/2026-07-18-phase-2-improvements.md`.

## 0.1.0 — 2026-07-18

First stable release. Verified end-to-end on all three engines — **Claude Code, Codex, and
OpenCode** — driving a real project.

- **Thin installer + default target = cwd.** `install.sh`/`install.ps1` run with no argument
  now install into the current directory, and arg parsing is position-agnostic. The target
  receives only agent-runtime files — all machinery (neutral `skills/`, `configs/`,
  `sync.sh`/`sync.ps1`, seed templates, `docs/extending.md`) stays in the forge-ai repo.
  `sync.sh`/`sync.ps1` gain `--out <dir>` to generate straight into the target. Engine configs
  become a generated baseline (per-project Claude overrides in `.claude/settings.local.json`);
  `state.template.md` moves to `shared/`. Upgrading an older, non-thin install self-heals
  (machinery removed; `configs/` and neutral `skills/` backed up to `*.pre-forge.bak`), gated
  on a prior forge install so a first install never touches unrelated dirs. Docs updated;
  `tests/smoke.sh` reworked to 9 cases with bash↔pwsh parity.
