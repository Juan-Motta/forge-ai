# Design — Portable hard enforcement (Fase 1)

**Date:** 2026-07-22
**Status:** design (pending implementation)
**Roadmap:** Fase 1 of "get codeforge to the level" (see docs/CHANGELOG + memory). Follows Fase 0
(check-gates identity, PR #16).

## Problem

codeforge's default install cannot **block** a bad ship on any engine. Enforcement today is:
Advisory (skills instruct) + a best-effort native prompt per engine (reads no gate state,
bypassable) + an **opt-in, Claude-only** `--with-hooks` PreToolUse hard block (`fails open`).
Cross-engine review (Codex + kimi-k3, 2026-07-22) named this the #1 gap: *"runs everywhere,
blocks nothing."* The three-engine council ranked portable hard enforcement the top priority.

## Goal

A hard block that (a) works **identically on Claude Code, Codex, and OpenCode**, (b) is **on by
default**, and (c) completes the honest enforcement ladder with a real **Verified** tier.

Non-goals: blocking local commits (breaks TDD); per-engine PreToolUse adapters; gating
`gh pr create` directly (covered transitively — a PR needs a pushed branch).

## Approach (decided during brainstorming)

Git is the one enforcement substrate common to all three engines: when any engine's shell runs
`git push`, git fires the repo's `pre-push` hook regardless of which CLI drove it. So the
portable hard block is a **committed git `pre-push` hook** activated via `core.hooksPath`.

| Decision | Choice | Why |
| --- | --- | --- |
| Mechanism | committed hooks dir + `core.hooksPath` | versioned (reviewable in PRs, travels with the repo), engine-neutral |
| Default posture | **ON by default**, `--advisory-only` opts out | closes the "blocks nothing" gap; the identity shift is documented honestly |
| Which hook | **pre-push only** | the real ship boundary; blocking commits breaks TDD (red-test commits); `gh pr create` needs a pushed branch so pre-push covers it |
| Existing `--with-hooks` | **replaced** | the portable pre-push supersedes the Claude-only PreToolUse; one mechanism |
| Location | `shared/hooks/pre-push` | consistent with the thin-install `shared/` payload |

## Components

### 1. The pre-push gate (core)

New committed file `src/shared/hooks/pre-push` → installed to the target as
`shared/hooks/pre-push`. A single POSIX `sh` script (git runs hooks via `sh` even on Windows via
Git-for-Windows' bundled shell, so **no `.ps1` variant is needed** — unlike `check-gates`, which
has both because each engine invokes it directly).

Logic (mirrors the retiring `claude-gate-hook.sh`, minus the PreToolUse stdin JSON):

```
run check-gates.sh (resolved relative to the repo root)
  exit 0  → gates complete           → allow push
  exit 1  → gates incomplete          → BLOCK push (print check-gates' detail)
  exit 3  → no .workflow/state.md      → allow (no active workflow — e.g. pushing docs)
  missing → check-gates not found      → warn + allow (fail-open on misconfiguration)
```

Per-push escape: `git push --no-verify` (honest — still Attested, not Verified). Permanent
escape: install with `--advisory-only`, or `git config --unset core.hooksPath`.

### 2. Installer changes (`install.sh` + `install.ps1`)

- Copy `shared/hooks/` into the target (thin payload); mark `pre-push` executable (`.sh` side;
  the `.ps1` installer sets the bit where applicable / relies on git's shebang).
- Default: run `git config core.hooksPath shared/hooks` in the target.
- `--advisory-only`: **do not** set `core.hooksPath` (pure advisory install).
- **Remove** the `--with-hooks` flag, `claude-gate-hook.{sh,ps1}`, and the settings.local.json
  gate-hook block. Auto-isolation of `.claude/settings.local.json` (claudeMdExcludes) stays.
- Guard-rails: not a git repo → warn + skip (as today); target already has a **custom**
  `core.hooksPath` (not ours) → do not clobber, warn.
- Upgrade path: an old install that has `claude-gate-hook.*` / `--with-hooks` settings → clean
  up the retired hook (remove the settings.local.json PreToolUse block we own; leave a
  user-owned settings.local.json untouched).

### 3. Verified-tier CI template

`src/docs/ci-templates/gates.yml` → installed to the target as `docs/ci-templates/gates.yml`
(reference, not auto-activated — same pattern as a Playwright bridge template). On PR it runs
`check-gates.sh` **bound to the PR commit, outside the agent's turn** (this is what makes it
*Verified*), plus a `# TODO: <your test command>` placeholder for the project's real tests /
verify-e2e recompute. Activated with `cp docs/ci-templates/gates.yml .github/workflows/`. This
is also the only backstop against a `--no-verify` bypass of the local pre-push.

### 4. Honest docs / philosophy update (required by the default flip)

The current docs advertise *"skills-and-config-only, no runtime hooks by default."* The flip to a
default-on pre-push contradicts that, so it must be rewritten truthfully:

- `src/CLAUDE.md` "Enforcement model" — default is now a portable git pre-push gate; `--no-verify`
  and `--advisory-only` are the escapes; the Claude-only PreToolUse is retired.
- `src/shared/rules/ship-gates.md` — reframe the ladder: **Advisory** (skills) → **Attested**
  (local pre-push + check-gates) → **Verified** (CI template, recomputed on the PR commit).
- `src/docs/extending.md` — drop/replace the Tier-C `--with-hooks` section.
- `README.md` "Status" + enforcement section — reflect default-on portable enforcement.

### 5. Tests

- **Smoke (`tests/smoke.sh` + `.ps1` parity):** default install sets `core.hooksPath=shared/hooks`;
  `--advisory-only` leaves it unset; non-git target skips with a warning; a pre-existing custom
  `core.hooksPath` is not clobbered; `shared/hooks/pre-push` is present and executable; the
  retired `claude-gate-hook.*` / `--with-hooks` no longer appear.
- **pre-push script unit tests (`tools/test/pre-push.test.mjs`):** in a temp git repo, a red
  state (unchecked gate) makes the hook exit non-zero (push blocked); a green state exits 0
  (allowed); no `.workflow/state.md` exits 0 (allowed); missing check-gates warns + allows.
  Drive the hook directly (`sh shared/hooks/pre-push </dev/null`) rather than a real push.

## Ship

- New default behavior → minor version bump (v0.6.0) at ship time.
- Feature branch `feat/portable-enforcement` → PR to `dev` (per the Fase 0 flow).
- Cross-engine code review (Codex) before ship; TDD throughout.
- Bug 2 from the Fase 0 review (E2E report freshness binds to the branch, not the exact HEAD) is
  in scope-adjacent territory but stays deferred unless the Verified CI template naturally
  subsumes it; note it, don't expand scope here.
