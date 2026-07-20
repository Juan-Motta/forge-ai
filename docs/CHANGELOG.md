# Changelog — forge-ai (framework)

Notable changes to the forge-ai framework itself, newest first. This is the framework's own
development log; it is **not** the seed shipped to installed projects (that lives at
`src/docs/CHANGELOG.md`).

## 0.4.0 — 2026-07-20

**Fix — `codex exec` hangs when an agent drives the council.** `shared/rules/models.md`'s
Codex invocation lacked `< /dev/null`, so a driver (e.g. Claude Code) running an advisor
through its shell tool left `codex exec` blocked on `Reading additional input from stdin...`
forever. Added `< /dev/null` to the table invocation and a new "Running these from an agent
(non-interactive)" section documenting both the stdin-block fix and the no-TTY stdout-drop
mitigation (`--output-last-message <file>`, one file per parallel advisor). Skills + config
only — no shim. Propagates to targets on the next install/upgrade.

New `verify-e2e` skill (→ 14 total) — journey-based E2E verification whose result is bound to
the ship-gate by a deterministic check, closing the top capability gap from the 3-engine
comparison vs claude-codex-forge (E2E verification was previously an unbound "exercise the
change" instruction). Pure skill + config, no runtime hooks; neutral `src/` source, identical
across Claude Code, Codex, and OpenCode.

- **`verify-e2e` skill.** Executes API/CLI user-journey use cases (Actor → Scenario → Intent →
  Setup → Steps → Verification → Persistence), validates journey shape before running, enforces
  the no-cheat ARRANGE/VERIFY boundary (no raw DB writes / internal endpoints / file-injection),
  applies execution safety (non-prod default, env-var credentials, secret/PII redaction), and
  writes a committed evidence report with a per-UC classification truth table. Passing use cases
  graduate to `docs/e2e/use-cases/` as a portable regression suite. UI is deferred to a v2
  Playwright bridge (recorded in `extending.md`).
- **Evidence-bound ship-gate (Attested).** The `standard` profile's bare "Change verified" box is
  **replaced** by `E2E verified` (count stays 6, so deleting it is still caught). `check-gates.sh`
  + `check-gates.ps1` bind the checked box to the report **PATH named in the box**
  (`(report: docs/e2e/reports/<file>.md)`) — not "any report in the directory". The named path
  must **exist** (resolved against the git toplevel), carry a **top-level `VERDICT: PASS`** (the
  first `VERDICT:` line, exactly `PASS`), and be **fresh on the branch** (git-detected —
  committed/staged/unstaged-edit/untracked since the merge-base, never mtime, which
  clone/checkout resets). A checked box that still names the `<...>` placeholder is rejected.
  **Base is auto-detected** by the closest merge-base among `dev`/`main`/`master`/`origin/…`
  (this framework integrates on `dev`, not `main`). **No silent fail-open:** when no base ref
  resolves, freshness is skipped with a stderr note but existence + top-level `PASS` are always
  enforced. Honest `— N/A:` escape (exact em-dash form) for internal/UI-only changes.
  bash↔pwsh parity verified byte-for-byte (including the em-dash marker), with real subprocess +
  temp-git-repo tests on both. **Cross-engine PR review (Codex gpt-5.6-sol + OpenCode kimi-k3)
  found the P0/P1 hole this closes:** the old check scanned for *any* fresh `PASS` report and
  hardcoded the base to `main`/`master`, so an unrelated or `dev`-inherited `PASS` could satisfy
  the gate with zero E2E run for the actual feature — and a missing `main`/`master` ref skipped
  the whole check (checked box + no report → exit 0).
- **Whole-branch review caught a gate-soundness bug** the per-task passes missed: `VERDICT: PASS`
  was matched on *any* report line, so a `FAIL` report carrying a per-UC `PASS` line satisfied the
  gate. Now anchored to the top-level verdict, with regression test `j`. Also tightened `N/A`
  detection to the `— N/A:` escape form (a mis-copied doc line can no longer silently skip the
  gate) and hardened ps1 native-git error handling for cross-version parity.
- **A second cross-engine adversarial review found and closed 3 more gate-bypass holes** in
  the named-path binding above: (1) a **leaf symlink** at the box-named path — pointing
  outside the repo at a fabricated `VERDICT: PASS` file — satisfied the old `[ -f ]`/`Test-Path
  -PathType Leaf` existence check, which follows symlinks; now rejected as a symlink *before*
  existence is even considered (though a symlinked ancestor directory remains a potential bypass). (2) **Path traversal** (`report: ../evil.md`, or a
  `docs/e2e/reports/../../evil.md` subdir trick) escaped the repo entirely when no base branch
  resolved (freshness skipped) — the box path is now validated against a strict whitelist,
  `^docs/e2e/reports/[A-Za-z0-9._-]+\.md$`, which also rejects any subdirectory and subsumes
  the old placeholder-only check. (3) A **multi-`(report: …)` line** made sh and ps1 disagree —
  sh's greedy `.*(report:` extraction picked the *rightmost* group, ps1's regex `Match` picked
  the *leftmost* — so a line pairing a placeholder group with a real fresh-PASS group could pass
  on one engine and fail on the other; a checked box naming more than one report is now rejected
  outright as ambiguous on both engines. All three closed at exact sh/ps1 parity with new
  regression tests (symlink, traversal, subdir, multi-report). **Honesty correction:** the
  "no silent fail-open" language in `ship-gates.md` was scoped to state precisely what
  `check-gates` proves — the box-named path is a whitelisted, non-symlink, existing, fresh
  `PASS` report — and explicitly that the report's *content* remains self-attested (**Attested**
  tier); only a CI job that re-runs `verify-e2e` itself (**Verified** tier) is bypass-proof.
- **Installers** scaffold `docs/e2e/{reports,use-cases}` into targets (both `install.sh` and
  `install.ps1`), with a smoke assertion. Tests: `npm run check` green — lint 14/0, routing eval
  93% (42 prompts), 38 tool tests.

## 0.3.0 — 2026-07-18

Two new skills (`adr`, `simplify` → 13 total), installer ergonomics (git awareness + `--git-init`,
default-on cross-engine auto-isolation via `claudeMdExcludes`), and a 4-engine council review that
fixed 5 real bugs and added a Windows CI job. Also: version stamping + `npx` from 0.2.0's tail.


- **Council-review fixes (5 real bugs + hardening).** A 4-engine review (Claude Opus 4.8 +
  Codex gpt-5.6-sol + opencode glm-5.2 + kimi-k3), every finding verified against the code:
  - **npx was broken on real platforms.** `bin/forge-ai.mjs` ran `sh install.sh`, but the script
    needs bash `pipefail` (dash — the `/bin/sh` on Debian/Ubuntu — aborts) → now runs `bash`.
    On Windows it forwarded POSIX `--flags` to `install.ps1`, which declares `-Switch` params →
    now translates them.
  - **The PowerShell gate hook was a silent no-op** — it read stdin into the reserved automatic
    `$input` (empty in `-File` mode), so `--with-hooks` never blocked on Windows. Fixed by
    reading into a normal variable; verified it now blocks a red ship.
  - **The gate hooks ignored their own fail-open contract** — a missing/unverifiable state
    (`check-gates` exit 3) was mapped to *block*, not *allow*. Both `.sh`/`.ps1` now fail open on
    non-`1` exits and only block on genuinely-unmet gates.
  - **`check-gates` didn't validate the profile's required gates** — a `standard` state with the
    gates deleted (or any 2 checked boxes) read green. It now enforces the required count per
    profile (standard = 6, light = 3) and rejects unknown profiles.
  - **Docs/config that lied**: `configs/codex/config.toml` claimed skills live in `.codex/skills`
    (they're `.agents/skills`); the README opening claimed "no runtime hooks / only scripts are
    installer + generator" (helper scripts ship + run in-turn); `extending.md` claimed sync
    generates `.codex/.opencode` skills. All corrected.
  - **Installer hardening**: the self-heal migration now fires only on a genuine old-install
    signal (its machinery) so a re-install never relocates a project's own top-level `configs/`
    or `skills/`; the manifest rule-prune now validates entries as bare `*.md` names (a committed,
    untrusted manifest can't drive a path-traversal delete).
  - **Closed the root cause — the untested paths.** Added a **Windows CI job** (install.ps1 +
    the npx wrapper's flag translation + the pwsh hook block/fail-open) and POSIX smoke cases for
    the npx entry point and the re-install self-heal guard. bash↔pwsh parity throughout; 16 smoke
    cases, 24 tool tests, all green. (Dropped one glm false positive — a claimed `gh pr create`
    glob bug that the code doesn't have.)
- **Auto-isolation from ancestor CLAUDE.md (default-on).** Codex (git-root scope) and OpenCode
  (first-AGENTS.md-wins) already confine to the project, but Claude Code walks to the filesystem
  root and concatenates *every* ancestor `CLAUDE.md`/`.claude/rules` into the project — so a
  forge-ai target nested under a directory with its own instructions silently inherits them
  (verified against Claude Code's memory docs; there is no `stop_traversal` setting yet).
  The installer now detects ancestor `CLAUDE.md`/`CLAUDE.local.md`/`.claude/rules` above the
  target and writes `claudeMdExcludes` into the gitignored `.claude/settings.local.json`, giving
  Claude Code the same project-scoped isolation as the other two engines. `--no-isolate`
  (`-NoIsolate`) keeps inheritance. The global `~/.claude` config is never excluded. Unified with
  `--with-hooks` into one settings-writer that forge-ai owns only when it created the file
  (tracked via a `localsettings:managed` manifest marker) — a `settings.local.json` you own is
  never clobbered. bash↔pwsh parity; smoke.sh gains an isolation case (14 total). Surfaced while
  dogfooding: an ancestor project's (outdated) security rule bled into a nested project's council.
- **Installer git awareness.** The workflow (branches/commits) and the ship gates operate on
  git, so the installer now checks whether the target is a repo. If it isn't, it prints an
  **advisory** (never touches VCS on its own — forge-ai's no-surprises ethos); pass `--git-init`
  (`-GitInit` / `npx forge-ai --git-init`) to have it run `git init` + a baseline
  `chore: adopt forge-ai` commit (skipped cleanly if git identity isn't configured). An existing
  repo is used as-is with no message. bash↔pwsh parity; smoke.sh gains a git case (13 total).

## 0.2.0 — 2026-07-18

Bundles all of Phase 2 (skill quality machinery, honest enforcement, anti-rationalization
anatomy) plus the first Phase-3 distribution work.

- **Phase 3 — opt-in hard-block gate (`--with-hooks`, Claude Code only).** `install.sh
  --with-hooks` (`-WithHooks` / `npx forge-ai --with-hooks`) installs a Claude Code `PreToolUse`
  hook into gitignored `.claude/settings.local.json` that runs `shared/scripts/claude-gate-hook.{sh,ps1}`
  — the same `check-gates` behind a hook — and **exits 2 to actually block** `git commit` /
  `git push` / `gh pr create` when the ship-gate boxes are incomplete. This is the one place
  forge-ai can hard-block; it's deliberately non-default (per-developer, Claude-specific so the
  cross-engine default stays portable, fails open if it can't verify, still *attested* not
  *verified*). Never clobbers existing local overrides. `ship-gates.md` / README / `extending.md`
  updated; smoke.sh gains a `--with-hooks` case (12 total) asserting it blocks a red ship and
  allows a green one.
- **Phase 3 — two new skills: `adr` and `simplify`** (13 skills total). `adr` records an
  architecture decision as an ADR (`docs/adr/<NNN>-<slug>.md`: context, decision, alternatives
  with why they lost, consequences) — closing the repo-first memory loop (`docs/adr/` was
  scaffolded but no skill wrote to it). `simplify` is a post-green, behavior-preserving cleanup
  pass (dead code, nesting, duplication, names; tests stay green throughout) — the refactor step
  is the first thing skipped under pressure, so it gets its own skill. Both carry the full
  anti-rationalization anatomy; `plan` now points at `adr` and `new-feature` at `simplify`.
  Routing evals updated (rank-1 95%, 0 collisions across 13 skills); strengthening surfaced a
  weak `new-feature` description (missing "implement/build" vocabulary), now fixed.
- **Phase 3 — version stamp + `npx` distribution.** A root `VERSION` file is now the single
  source of truth; the installers stamp it into `.forge-version` in the target and print a
  direction-aware **drift advisory** on `--upgrade` when the target's recorded version differs
  (informational, never blocks). New `npx forge-ai [target] [--upgrade]` entry point: a
  dependency-free Node wrapper (`bin/forge-ai.mjs`) runs the platform installer bundled in the
  npm package, so a project can adopt forge-ai with no repo clone (`--version` / `--help`
  supported). `package.json` is now a publishable `forge-ai` package (`files` whitelist ships
  the `src/` payload + install scripts, and excludes the dev-only `tools/`); a version-sync test
  binds `VERSION` to `package.json`. smoke.sh gains a `.forge-version` case (now 11). NOTE:
  publishing to npm requires confirming the `forge-ai` package name is available (or scoping it).
- **Phase 2 — honest tiered enforcement (priority #2): `check-gates` + Verified/Attested/Advisory.**
  New **Tier-B** validator `shared/scripts/check-gates.{sh,ps1}` (POSIX + PowerShell parity) reads
  `.workflow/state.md`, confirms every ship-gate box for the active profile is checked (or N/A),
  and exits non-zero listing any that aren't — turning "eyeball the file" into "run a command that
  fails loudly." It ships as a runtime payload (installers copy `shared/scripts/`), and
  `finish-branch` step 1 now invokes it. `ship-gates.md` gains the **Verified / Attested / Advisory**
  vocabulary: the check validates the *record*, not the work (a checked box is an attestation, not
  proof); a real *verified* gate means running it in CI with branch protection. The README
  enforcement section is rewritten to stop over-selling the native prompt. smoke.sh gains a
  check-gates case (green passes, unchecked box fails, missing state errors) — now 10 cases.
- **Phase 2 — anti-rationalization anatomy (priority #3): all 11 skills retrofitted.** Each
  skill now carries a skill-specific **Common Rationalizations** table (the excuses an agent
  uses to skip a step, each rebutted), a **Red Flags** section, and an exit-criteria
  **Verification** checklist. In a no-hooks advisory system this anatomy *is* the enforcement —
  it's the layer that holds the process under time/sunk-cost/authority pressure. The linter now
  treats all three sections as hard errors (a new skill ships with the rebuttals or it doesn't
  ship). Lint + evals + 22 tests + smoke all green.
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
