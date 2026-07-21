# Design — Interactive setup console (Ink TUI) for codeforge

**Date:** 2026-07-20
**Status:** Approved (brainstorming) — pending spec review → implementation plan
**Author:** driver + user

## Problem

Installing codeforge today is non-interactive: `npx @jualopezmo/codeforge` (or the clone
`install.sh`) copies the payload with flags (`--with-hooks`, `--git-init`, `--no-isolate`).
There is no guided first-run experience. Two gaps:

1. **No orientation.** A new user doesn't see which engines (Claude / Codex / OpenCode) are
   installed, and has no guided way to set the project's options.
2. **Review policy is invisible and manual.** codeforge's core value is cross-engine review
   ("driver on one engine, reviewer on another"). Which engine + model acts as reviewer lives
   in `shared/rules/models.md`, hand-edited. A user has to know to edit it. The desired UX is:
   configure the default review policy **once** at setup, then just say *"revisa"* or *"revisa
   con codex"* during work and codeforge already knows which engine/model to spawn — without
   re-specifying the model each time.

## Goal

A beautiful, modern, full-terminal interactive setup console (default experience) that:
- Detects which engines are installed (informational — you do NOT need all three).
- Configures the **default review policy** (default reviewer engine(s) + model/effort per
  engine), imprinted into `shared/rules/models.md`.
- Configures project options (PROJECT.md fields, `--git-init`, `--no-isolate`, `--with-hooks`,
  default gate profile).
- Delegates the actual install to the proven `install.sh` / `install.ps1`, then applies
  configuration as post-install edits.
- Falls back to non-interactive install automatically when there is no TTY (CI/pipes) or when
  flags are passed.

## Non-goals

- Reimplementing the shell installer logic in Node (self-heal, isolation, sync generation stay
  in `install.sh`/`install.ps1`).
- Making any engine mandatory. The detector informs configuration; it never blocks.
- A general project dashboard / ongoing TUI. This is a **first-run setup** wizard (re-runnable
  via `--upgrade` context later, but scoped to setup here).

## Key decisions (from brainstorming)

| Decision | Choice |
| --- | --- |
| TUI technology | **Node + Ink** (React for CLI). codeforge already requires Node for `npx`. |
| Wizard vs installer | Wizard is a **front-end that delegates** to `install.sh`/`install.ps1`; never reimplements it. |
| Trigger | **UI is the default.** Basic `npx @jualopezmo/codeforge` → interactive UI. Flags → non-interactive. No TTY → non-interactive fallback (mechanical, for CI). |
| Config scope | Engine detection, default review policy (models), gates profile default + `--with-hooks`, project (PROJECT.md + git + isolation). |
| Model config applied via | **Post-install edits** to generated target files (`models.md`, `PROJECT.md`, `state.template.md`), not new flags threaded through install.sh (though non-interactive parity flags are added — see §Non-interactive parity). |
| Runtime dependency | `ink` + `react` become **runtime `dependencies`**. Accepted trade-off: codeforge is no longer zero-runtime-dep (the clone `install.sh` path stays dep-free; only the wizard needs Node). |

## Architecture

### Entry flow (`bin/codeforge.mjs`)

The existing thin wrapper gains a branch:

```
parse argv
if (no install flags AND no target AND process.stdout.isTTY AND process.stdin.isTTY):
    → launch the Ink wizard (cli/index.mjs)
else:
    → current behavior: spawn install.sh (POSIX) / install.ps1 (Windows) with the args
```

"Install flags" = `--upgrade`, `--with-hooks`, `--git-init`, `--no-isolate`, an explicit target
dir, or `--yes`/`--non-interactive`. `--version`/`--help` short-circuit as today.

### Repo layout / packaging

- New top-level **`cli/`** directory, shipped via `package.json` `files[]`:
  - `cli/index.mjs` — Ink app entry (renders the wizard).
  - `cli/components/` — Ink components per screen (splash, detect, review-policy, gates,
    project, summary).
  - `cli/lib/detect.mjs` — engine detection (`which` + `--version`).
  - `cli/lib/models-catalog.json` — curated model options per engine (+ effort levels) with a
    "custom" escape hatch.
  - `cli/lib/apply.mjs` — the post-install "applier": edits `models.md`, `PROJECT.md`,
    `state.template.md` in the target.
  - `cli/lib/run-installer.mjs` — spawns `install.sh`/`install.ps1` with mapped flags, streams
    output, returns exit status.
  - `cli/assets/anvil.ans.mjs` — precomputed ANSI pixel-art of the codeforge anvil icon
    (exported string; no runtime image decoding).
  - `cli/lib/flags.mjs` — the answers→flags mapping (shared by the wizard summary and the
    non-interactive path).
- `ink` + `react` added to `package.json` `dependencies`.
- `tools/` (dev-only) is unchanged and still excluded from the package.

### Wizard screens

1. **Splash** — renders `cli/assets/anvil.ans.mjs` (the pixel-art anvil) full-width, title
   `codeforge`, version, one-line tagline. Enter to continue.
2. **Engine detection** — runs `detect.mjs`; shows a status table:
   `Claude ✓ 1.x` / `Codex ✓ gpt-… CLI x.y` / `OpenCode ✗ (install: …)`. Purely informational;
   it seeds the choices available in the next screen. Never blocks.
3. **Review policy** (the centerpiece) — configure, per available engine, the model + effort,
   and choose the **default reviewer(s)** — which engine(s) run when the user just says
   *"revisa"*. Options come from `models-catalog.json` with a free-text "custom" fallback and a
   **cost mode** toggle (cheaper presets). Enforces reviewer ≠ driver conceptually (informational
   note; driver is whatever CLI the user opens).
4. **Gates + hooks** — toggle `--with-hooks` (offered only if Claude is detected) and the
   **default** gate Profile written to `state.template.md` (`standard` | `light`). Profile is
   per-workflow at runtime; this only sets the seed default.
5. **Project + git + isolation** — target dir (default cwd), `PROJECT.md` fields
   (persona / info / special rules), `--git-init` (offered if target is not a git repo),
   `--no-isolate` (offered if an ancestor `CLAUDE.md` is detected).
6. **Summary + confirm** — shows every choice AND the equivalent **non-interactive command**
   (so it's reproducible in CI). On confirm: run installer → apply post-install edits → show
   the installer's validation report + a "what was configured" recap.

### Execution pipeline (on confirm)

```
answers
  → run-installer.mjs: spawn install.sh/install.ps1 with [target, --with-hooks?, --git-init?, --no-isolate?]
  → (installer copies payload, generates engine artifacts, runs its own post-install validation)
  → apply.mjs (post-install edits in the target):
        · shared/rules/models.md      ← chosen models/effort + default reviewer set
        · PROJECT.md                  ← persona / info / special rules (only if fields provided)
        · shared/state.template.md    ← default Profile line
  → recap + installer validation output
```

`apply.mjs` edits are idempotent and target the generated files by anchored markers, not blind
string replace, so re-runs / `--upgrade` don't corrupt them.

### models.md as the review-policy source

`shared/rules/models.md` already holds a per-engine model table and a role→engine table. The
wizard makes it concrete:
- Per-engine **Model + Effort** rows (Codex `gpt-5.6-sol`/xhigh, OpenCode `kimi-k3`, Claude
  `opus`/high, or user's choice).
- A **default reviewer set** (which engine(s) answer a bare *"revisa"*), so the workflow can
  resolve `revisa` / `revisa con codex` / `council` without the user re-specifying a model.

The skills (`review`, `council`, `fix-bug`, `new-feature`, `research`) already read invocation
from `models.md`, so no skill changes are required — only the target's `models.md` content is
made concrete by the wizard.

## Non-interactive parity (mandatory)

Every wizard choice has a flag/env equivalent, and the summary screen prints the exact command.
New flags/env are introduced for the settings that install.sh doesn't cover today (models,
PROJECT, profile). Candidate surface (finalized in the implementation plan):

- `--yes` / `--non-interactive` — never launch the UI.
- `--reviewer=<engine[:model[:effort]]>` (repeatable) — sets default reviewer(s) + per-engine model.
- `--profile=<standard|light>` — default gate profile seed.
- `--project-persona=…`, `--project-info=…` — PROJECT.md fields (or `--config <file.json>` for all).
- Existing: `--with-hooks`, `--git-init`, `--no-isolate`, `[target]`.

No-TTY (CI) with no flags falls back to defaults (same as today's bare install) — it never hangs.

## Splash + theme

- The pixel-art anvil icon is converted once to 24-bit ANSI half-block art and committed as
  `cli/assets/anvil.ans.mjs`. Runtime just prints it — no image-decode dependency.
- Color theme derived from the icon palette: navy background, steel-blue structure, incandescent
  orange for actions/accents, cyan (`</>`) for focus/selection.
- The theme respects `NO_COLOR` and degrades on non-truecolor terminals.

## Testing

- **Unit** (Node `--test`):
  - `detect.mjs` — mock `which`/spawn; asserts installed/missing/version parsing.
  - `apply.mjs` — run against a temp copy of a generated target; assert `models.md`,
    `PROJECT.md`, `state.template.md` edited correctly and idempotently.
  - `flags.mjs` — answers → non-interactive command mapping (round-trip).
- **Component** — `ink-testing-library` renders each screen; asserts key interactions and the
  summary command output.
- **Smoke** — the existing `tests/smoke.sh` "npx entry point" case must still pass (non-TTY →
  non-interactive install). Add a case asserting the bin falls back to non-interactive when
  stdin/stdout are not a TTY.

## Risks & mitigations

- **New runtime dependency (ink/react).** Changes codeforge's zero-dep posture. Mitigation:
  documented explicitly; clone `install.sh` path stays dep-free (only the wizard needs Node,
  already required for `npx`).
- **Windows.** Ink runs under Node on Windows; wizard delegates to `install.ps1`. Verify PTY /
  key handling under `pwsh` in the plan.
- **Model catalog staleness.** Mitigation: `models-catalog.json` is only editable defaults; the
  "custom" free-text option is always available; model IDs live in the tool layer (not skills,
  so the skill-linter model-id quarantine is unaffected).
- **Post-install edit fragility.** Mitigation: anchored markers + idempotent edits + unit tests
  against a real generated target.

## Open items for the implementation plan

- Exact non-interactive flag surface (vs a single `--config file.json`).
- `models.md` marker format for the applier to edit safely.
- Whether the default reviewer set needs a new explicit block in `models.md` or can be expressed
  in the existing role→engine table.
- Windows key/PTY verification for Ink under `pwsh`.
