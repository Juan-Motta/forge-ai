# Design: thin installer + default target = cwd

**Date:** 2026-07-17
**Branch:** `feat/thin-installer`
**Status:** approved (brainstorming)

## Problem

Two issues with the current installer (`install.sh` / `install.ps1`):

1. **No default target.** Running the installer with no positional argument errors out
   (`usage: ... <target-dir>`). The user wants a bare run to install into the current
   working directory.

2. **The target is bloated with framework machinery.** The current model copies the whole
   neutral source (`src/*`) into the target and then runs `sync.sh` there. The result is
   that every installed project carries:
   - **three copies of every skill** — the neutral `skills/`, plus the generated
     `.claude/skills/` and `.agents/skills/`;
   - `configs/` (only a generation input — never read at runtime);
   - `sync.sh` / `sync.ps1` (regeneration machinery);
   - `PROJECT.template.md`, `CONTINUITY.template.md`, `docs/extending.md` (seed/doc-only).

   The user wants only what the **agent needs at runtime** to live in the target. All
   machinery (scripts, generation source) stays in the forge-ai repo.

## What the agent actually needs at runtime (verified)

Grepped `src/skills/**` and `src/CLAUDE.md` for runtime path references:

- `shared/rules/*.md` — referenced **by path** from `CLAUDE.md` and most skills → must exist
  in the target.
- `state.template.md` — skills copy it to `.workflow/state.md` at workflow start (3
  references, all bare-name) → must exist in the target.
- `configs/` — **not** referenced by any skill; only a `sync` input.
- `sync.sh` / `sync.ps1` — **not** referenced by any skill; pure machinery.

## Decisions (agreed during brainstorming)

- **Default target = current working directory (`$PWD`).**
- **Thin, centralized model.** The target receives only runtime files. Upgrades and
  customization are driven from the forge-ai repo (edit source, re-run
  `install.sh --upgrade <target>`). No machinery in the target.
- **`state.template.md` moves to `shared/state.template.md`** (out of the root; next to the
  other committed discipline the agent reads). Update the 3 references.
- **`.gitignore` handling stays exactly as-is** (merge, append-only, sentinel-guarded,
  never clobbers an existing file). Generated engine artifacts remain **committed** in the
  target so a fresh clone works with no forge-ai dependency.

## Design

### 1. Target resolution + arg parsing (requirement #1)

`TARGET` defaults to `$PWD` when no positional argument is given. Flag parsing becomes
position-agnostic so `--upgrade` works with or without an explicit dir:

- `./install.sh` → install into cwd
- `./install.sh --upgrade` → upgrade cwd
- `./install.sh <dir> [--upgrade]` → unchanged

Parsing loop: iterate args; `--upgrade` sets `MODE=upgrade`; the first non-flag arg sets
`TARGET`; unknown flags error with usage. After resolution, `TARGET` defaults to `$PWD`.

The existing **self-install guard** is preserved and must still fire when cwd is the
forge-ai repo: refuse if the resolved `TARGET` equals the script dir (`$SRC`) or the
payload dir (`$PAYLOAD`). Running `./install.sh` from inside forge-ai with no args must
error clearly rather than install onto itself.

### 2. Thin payload

**Copied into the target (runtime only):**

```
CLAUDE.md                                    (managed)
AGENTS.md, opencode.json                     (generated)
.claude/skills/…, .claude/settings.json      (generated)
.agents/skills/…                             (generated)
.codex/config.toml                           (generated)
shared/rules/*.md                            (managed; project-owned rules preserved on upgrade)
shared/state.template.md                     (managed; runtime template — moved out of root)
PROJECT.md, CONTINUITY.md                    (project-owned; seeded if missing, never clobbered)
docs/CHANGELOG.md                            (project-owned; seeded if missing)
docs/{prds,plans,research,solutions,adr}/.gitkeep   (scaffolding)
.forge-manifest, .gitignore                  (internal)
```

**Stays in forge-ai only (never copied):**

```
skills/                                      (neutral source — was duplicated 3× in target)
configs/                                     (generation input for the engine configs)
sync.sh, sync.ps1                            (regeneration machinery)
PROJECT.template.md, CONTINUITY.template.md  (seed-only)
docs/extending.md                            (how-to-extend-forge-ai doc)
```

Resulting target root is just: `CLAUDE.md`, `AGENTS.md`, `PROJECT.md`, `CONTINUITY.md`,
`opencode.json` + dirs `shared/`, `docs/`, `.claude/`, `.agents/`, `.codex/`.

### 3. Generation mechanism (`sync --out`)

Today `install` copies `src/*` to the target and runs `target/sync.sh`. Since the target
will no longer contain the source or `sync`, refactor `sync.sh` / `sync.ps1` to separate
**source root** from **output root**:

- `sync.sh` (no args) → source = output = script dir. **Current behavior unchanged**
  (forge-ai dogfooding into `src/` still works; the smoke test's standalone-sync case still
  applies).
- `sync.sh --out <dir>` → read inputs from the script's project (`src/`), write engine
  artifacts (`AGENTS.md`, `opencode.json`, `.claude/{skills,settings.json}`,
  `.agents/skills`, `.codex/config.toml`) into `<dir>`.

`install.sh` then:

1. Resolve `TARGET`, `MODE`; run guards.
2. Copy the runtime non-generated files from `PAYLOAD` → `TARGET`
   (`CLAUDE.md`, `shared/rules/*.md`, `shared/state.template.md`, `docs/` scaffolding +
   `CHANGELOG.md`), seeding `PROJECT.md` / `CONTINUITY.md` from `src` templates if missing.
3. Run `sync.sh --out "$TARGET"` to generate the engine artifacts directly into the target.
4. Write `.forge-manifest`, merge `.gitignore`, emit gate warnings, run post-install
   validation.

### 4. Centralization tradeoffs (accepted)

- **Skills:** `.claude/skills` and `.agents/skills` become fully generated/managed. A
  project-specific skill lives in forge-ai, not in the target. The existing data-loss guard
  (a pre-existing, non-forge `.claude/skills` or `.agents/skills` without the
  `.forge-generated` marker is backed up to `*.pre-forge.bak`) is preserved.
- **Engine configs:** `settings.json` / `config.toml` / `opencode.json` become a generated
  baseline from forge-ai. Per-project Claude overrides go in `.claude/settings.local.json`
  (already gitignored, never touched). Project-owned `shared/rules/*.md` still survive
  upgrades via the manifest-driven selective preserve/prune.

### 5. Manifest / prune

Skills are now fully mirrored by `sync` (wipe + regenerate), so skill-level selective prune
is moot. The `.forge-manifest` narrows to tracking framework **rules** for upstream-removal
prune: a `rule:*` entry present in the manifest but absent from the current payload is a
framework rule removed upstream → delete it; project-owned rules are never in the manifest
→ untouched.

### 6. `.gitignore`

Unchanged: `touch` + sentinel-guarded append of the forge block
(`.DS_Store`, `.workflow/`, `.claude/settings.local.json`). Never clobbers an existing
file; idempotent on re-run.

### 7. Parity + platform

Every change above lands identically in `install.ps1` / `sync.ps1`. The smoke test's
bash↔pwsh byte-identical parity check must stay green.

### 8. `next:` message

The post-install message drops the "re-run `./sync.sh`" guidance (no sync in the target).
New guidance: to customize or upgrade, edit the forge-ai source and re-run
`install.sh --upgrade <target>`.

## Tests (`tests/smoke.sh` + pwsh parity)

- **#1 (no leak):** extend the leak assertion to require that `skills/`, `configs/`,
  `sync.sh`, `sync.ps1`, `PROJECT.template.md`, `CONTINUITY.template.md`, and
  `docs/extending.md` are **absent** from the target. Assert `shared/state.template.md`
  exists and root `state.template.md` does not.
- **#2 (parity):** unchanged — bash and pwsh targets must be byte-identical.
- **#3 / #6 (upgrade preserve/prune):** rewrite for the centralized model. Custom skills are
  no longer in `target/skills/`; the preserve/prune assertions move to
  `target/shared/rules/` (a project-owned rule survives upgrade; a framework rule dropped
  upstream is pruned).
- **#4 (data-loss guard):** unchanged — a user's own pre-existing engine skills dir is
  backed up.
- **#5 (sync fails on missing input):** adjust to the new `sync --out` signature.
- **New:** assert that a bare `./install.sh` (no args) installs into cwd, and that a bare
  run from inside the forge-ai repo is refused.

## Out of scope

- Per-project skill/config overlays in the target (deferred; centralized model chosen).
- Hook-based conditional ship-gate blocking (unchanged; still advisory + native prompts).
