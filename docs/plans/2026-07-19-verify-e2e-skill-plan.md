# verify-e2e Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `verify-e2e` skill to forge-ai that executes API/CLI user-journey use cases, writes a committed evidence report, and binds an attested ship-gate box to a fresh `VERDICT: PASS` report via `check-gates.sh`/`.ps1`.

**Architecture:** Pure `SKILL.md` + edits to the deterministic gate validator. No runtime hooks, no new dependencies. The skill is a markdown instruction set discovered by all three engines; enforcement is one new named-marker + git-freshness + verdict check inside the existing `check-gates` scripts. Design source: `docs/plans/2026-07-19-verify-e2e-skill-design.md`.

**Tech Stack:** POSIX `sh`, PowerShell 7 (`pwsh`), Node ≥20 test runner (`node --test`), the repo's own `tools/lint-skills.mjs` and `tools/run-evals.mjs`.

## Global Constraints

- **Neutral source only.** Edit under `src/` (and repo-root `tools/`, `install.sh`, `install.ps1`). Never hand-edit generated engine artifacts (`.claude/`, `.agents/`, `.codex/`, `AGENTS.md`).
- **Three-engine parity.** Every `check-gates.sh` behavior change must be mirrored in `check-gates.ps1`, verified by a test fixture.
- **`standard` profile stays at exactly 6 gate boxes** (`ship-gates.md`, `check-gates.sh:56`, `check-gates.ps1:53`). The E2E box **replaces** the existing "Change verified…" box — never adds a 7th.
- **Skill index parity is a hard linter error** (`tools/lib/skill-lint.mjs:118-119`): a new skill dir MUST be listed in `src/CLAUDE.md`.
- **Routing eval fails on lexical collision ≥0.75** (`tools/run-evals.mjs`): the new skill description must be distinct from `finish-branch`/`new-feature` "verify…end to end" wording.
- **No secrets in committed files.** UC credentials come from env vars; report output is redacted.
- **Gate marker string (contract, used verbatim across files):** the checklist line begins `- [ ] E2E verified via verify-e2e` and the N/A escape is `- [x] E2E verified — N/A: <reason>`.
- **Verify commands:** `npm run check` (runs `lint:skills` + `eval:routing` + `test:tools`). Individual: `npm run lint:skills`, `npm run eval:routing`, `node --test tools/test/<file>`.
- **Commit discipline:** conventional commits; end message with the repo's Co-Authored-By trailer if configured. Commit at the end of each task.

## File structure

| File | Responsibility | Task |
| --- | --- | --- |
| `src/shared/rules/ship-gates.md` | Replace the verify box in `standard`; add Attested-tier prose | 1 |
| `src/shared/state.template.md` | Mirror the box replacement into the checklist template | 1 |
| `src/shared/scripts/check-gates.sh` | Named-marker + verdict + git-freshness E2E check | 2 |
| `tools/test/check-gates.test.mjs` | Unit tests for the sh E2E check (8 cases) | 2 |
| `src/shared/scripts/check-gates.ps1` | PowerShell parity of the E2E check | 3 |
| `tools/test/check-gates.ps1.test.mjs` | Parity fixture (skipped if no `pwsh`) | 3 |
| `src/skills/verify-e2e/SKILL.md` | The skill itself | 4 |
| `src/CLAUDE.md` | Register `verify-e2e` in the skill index | 4 |
| `tools/evals/routing-cases.json` | Positive + negative routing cases | 5 |
| `src/shared/rules/docs-layout.md` | Register `docs/e2e/` | 6 |
| `src/docs/e2e/{reports,use-cases}/.gitkeep` | Scaffold seeds | 6 |
| `install.sh`, `install.ps1` | Scaffold `docs/e2e/{reports,use-cases}` into targets | 6 |
| `src/skills/new-feature/SKILL.md` | Verify step → run verify-e2e | 7 |
| `src/skills/fix-bug/SKILL.md` | Add verify-e2e (keep repro/neighbor checks) | 7 |
| `src/skills/finish-branch/SKILL.md` | Note the gate now enforces the E2E marker | 7 |
| `src/docs/extending.md` | Document v2 (Playwright, UI adapter, multi-surface) | 7 |

---

### Task 0: Branch setup

- [ ] **Step 1: Create the feature branch**

Run:
```bash
git checkout -b feat/verify-e2e-skill
```
Expected: `Switched to a new branch 'feat/verify-e2e-skill'`

- [ ] **Step 2: Start workflow state**

```bash
cp src/shared/state.template.md .workflow/state.md 2>/dev/null || cp shared/state.template.md .workflow/state.md
```
Set `Skill: new-feature`, `Profile: standard`, `Feature: verify-e2e-skill`, `Branch: feat/verify-e2e-skill` in `.workflow/state.md`. (No commit — `.workflow/` is gitignored.)

---

### Task 1: Replace the verify gate box (contract first)

Defines the `E2E verified` marker every later task keys on. Doing this first locks the string contract.

**Files:**
- Modify: `src/shared/rules/ship-gates.md` (the `standard` profile list + a prose line)
- Modify: `src/shared/state.template.md:23` (the `standard` checklist)

**Interfaces:**
- Produces: the exact checklist line `- [ ] E2E verified via verify-e2e (report: docs/e2e/reports/<...>.md)` and the N/A form `- [x] E2E verified — N/A: <reason>`. Tasks 2 and 3 match on the prefix `E2E verified`.

- [ ] **Step 1: Replace the box in `ship-gates.md`**

In `src/shared/rules/ship-gates.md`, under `### standard`, replace the line:
```markdown
- [ ] Change verified by actually exercising it
```
with:
```markdown
- [ ] E2E verified via verify-e2e (report: docs/e2e/reports/<...>.md) — `N/A: <reason>` allowed for purely internal changes (migration, refactor, tooling) and UI-only changes (no v1 adapter)
```

- [ ] **Step 2: Add the tier-honesty prose**

Immediately after the `standard` list in `ship-gates.md`, add:
```markdown
> The `E2E verified` box is an **Attested** signal: it asserts that a verify-e2e run
> produced a `VERDICT: PASS` report committed under `docs/e2e/reports/`. `check-gates`
> binds the box to that artifact, but the report is still the agent's own output — it is
> not the Verified tier (which requires an out-of-turn recompute in CI). See the
> Verified / Attested / Advisory ladder above.
```

- [ ] **Step 3: Mirror into `state.template.md`**

In `src/shared/state.template.md`, in the `## Ship-gate checklist` block, replace:
```markdown
- [ ] Change verified by exercising it
```
with:
```markdown
- [ ] E2E verified via verify-e2e (report: docs/e2e/reports/<...>.md)
```

- [ ] **Step 4: Verify the count invariant still holds**

Run:
```bash
awk '/^## Ship-gate checklist/{f=1;next} /^## /{f=0} f&&/^- \[[ xX]\]/{n++} END{print n}' src/shared/state.template.md
```
Expected: `6`

- [ ] **Step 5: Commit**

```bash
git add src/shared/rules/ship-gates.md src/shared/state.template.md
git commit -m "feat(gates): replace bare verify box with E2E verified marker"
```

---

### Task 2: `check-gates.sh` — E2E evidence check (TDD)

The keystone. Bind a checked `E2E verified` box (not N/A) to a fresh `VERDICT: PASS` report, using git — not mtime — for freshness, with graceful degradation.

**Files:**
- Create: `tools/test/check-gates.test.mjs`
- Modify: `src/shared/scripts/check-gates.sh` (insert the E2E check after the existing unmet-boxes block, before the final success echo at `:81`)

**Interfaces:**
- Consumes: the marker `E2E verified` from Task 1.
- Produces: exit codes — `0` complete/skipped, `1` E2E box checked without a fresh PASS report (or N/A with empty reason). Reused by Task 3 (ps1 must match) and Task 7 (finish-branch relies on it).

- [ ] **Step 1: Write the failing tests**

Create `tools/test/check-gates.test.mjs`:
```javascript
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const script = join(repoRoot, 'src', 'shared', 'scripts', 'check-gates.sh');

function git(cwd, ...args) {
  execFileSync('git', args, { cwd, stdio: 'pipe' });
}

// Build a temp git repo with main + a feature branch, a state file, and optional report.
function setup({ box, report, onDefaultBranch = false } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
  git(dir, 'init', '-q', '-b', 'main');
  git(dir, 'config', 'user.email', 't@t');
  git(dir, 'config', 'user.name', 't');
  writeFileSync(join(dir, 'seed'), 'x');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed');
  if (!onDefaultBranch) git(dir, 'checkout', '-q', '-b', 'feat/x');

  const boxLine = box ?? '- [x] E2E verified via verify-e2e (report: docs/e2e/reports/r.md)';
  const state = `# State
## Active workflow
- **Profile:** standard
## Ship-gate checklist
- [x] On a feature branch (not \`main\`)
- [x] Plan written and design-reviewed by the other engine
- [x] Tests written (TDD) and passing
- [x] Code review clean — no open P0/P1/P2
${boxLine}
- [x] State updated
`;
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'), state);

  if (report !== undefined) {
    mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
    writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'r.md'), report);
    if (report.__committed) git(dir, 'add', 'docs'), git(dir, 'commit', '-qm', 'report');
  }
  return dir;
}

function run(dir) {
  try {
    execFileSync('sh', [script, '.workflow/state.md'], { cwd: dir, stdio: 'pipe' });
    return 0;
  } catch (e) { return e.status; }
}

test('a: box checked + fresh PASS report → exit 0', () => {
  const dir = setup({ report: 'VERDICT: PASS\n' });
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});

test('b: box checked + no report → exit 1', () => {
  const dir = setup({ report: undefined });
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});

test('c: box checked + report VERDICT FAIL → exit 1', () => {
  const dir = setup({ report: 'VERDICT: FAIL\n' });
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});

test('d: box checked + report committed on main (not fresh on branch) → exit 1', () => {
  // Report exists on main before branching → not in merge-base..HEAD diff, not untracked.
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
  git(dir, 'init', '-q', '-b', 'main');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
  writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'r.md'), 'VERDICT: PASS\n');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed+report');
  git(dir, 'checkout', '-q', '-b', 'feat/x');
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'),
`## Active workflow
- **Profile:** standard
## Ship-gate checklist
- [x] a
- [x] b
- [x] c
- [x] d
- [x] E2E verified via verify-e2e (report: docs/e2e/reports/r.md)
- [x] f
`);
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});

test('e: N/A with reason → exit 0', () => {
  const dir = setup({ box: '- [x] E2E verified — N/A: internal refactor', report: undefined });
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});

test('f: N/A with empty reason → exit 1', () => {
  const dir = setup({ box: '- [x] E2E verified — N/A:', report: undefined });
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});

test('g: on default branch (no merge-base) → skip → exit 0', () => {
  const dir = setup({ report: undefined, onDefaultBranch: true });
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});

test('h: old 6-box state without E2E box name still passes count, unaffected → exit 0', () => {
  const dir = setup({ box: '- [x] Change verified by exercising it', report: undefined });
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
node --test tools/test/check-gates.test.mjs
```
Expected: tests `a`, `c`, `d`, `f` FAIL (current script ignores the E2E marker entirely, so it exits 0 for all-checked states). `b`, `e`, `g`, `h` may pass incidentally.

- [ ] **Step 3: Implement the E2E check in `check-gates.sh`**

In `src/shared/scripts/check-gates.sh`, insert the following **between** the closing `fi` of the `if [ "$unmet" -gt 0 ]` block (line 79) and the final success `echo` (line 81):
```sh
# --- E2E evidence check (Attested) --------------------------------------------
# If the "E2E verified" box is checked as a real run (not "— N/A: <reason>"),
# require a report under docs/e2e/reports/ that is BOTH fresh on this branch
# (git, not mtime — clone/checkout resets mtimes) AND VERDICT: PASS.
e2e_line=$(awk '
  /^##[[:space:]]+Ship-gate checklist/ { inlist = 1; next }
  /^##[[:space:]]/                     { inlist = 0 }
  inlist && /^- \[[xX]\][[:space:]]+E2E verified/ { print; exit }
' "$STATE")

if [ -n "$e2e_line" ]; then
  case "$e2e_line" in
    *"N/A:"*)
      # N/A escape must carry a non-empty reason.
      reason=$(printf '%s' "$e2e_line" | sed -n 's/.*N\/A:[[:space:]]*\(.*\)$/\1/p')
      if [ -z "$reason" ]; then
        echo "check-gates: 'E2E verified' uses 'N/A:' with no reason — treated as unmet." >&2
        exit 1
      fi
      ;;
    *)
      # Real E2E claim — need a fresh PASS report. Degrade gracefully when git
      # can't resolve a branch point (not a repo, on default branch, no merge-base).
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        default_branch=""
        for b in main master; do
          if git show-ref --verify --quiet "refs/heads/$b"; then default_branch="$b"; break; fi
        done
        current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        base=""
        if [ -n "$default_branch" ] && [ "$current" != "$default_branch" ]; then
          base=$(git merge-base HEAD "$default_branch" 2>/dev/null || echo "")
        fi
        if [ -n "$base" ]; then
          changed=$(git diff --name-only "$base"..HEAD -- docs/e2e/reports/ 2>/dev/null || echo "")
          untracked=$(git ls-files --others --exclude-standard -- docs/e2e/reports/ 2>/dev/null || echo "")
          found=""
          for f in $changed $untracked; do
            [ -f "$f" ] || continue
            if grep -Eq '^VERDICT:[[:space:]]*PASS([[:space:]]|$)' "$f"; then found="$f"; break; fi
          done
          if [ -z "$found" ]; then
            echo "check-gates: 'E2E verified' is checked, but no report in docs/e2e/reports/ is" >&2
            echo "  both changed on this branch (since $default_branch) and 'VERDICT: PASS'." >&2
            echo "  Run the verify-e2e skill, or use '— N/A: <reason>' for internal/UI-only changes." >&2
            exit 1
          fi
        fi
      fi
      ;;
  esac
fi
# --- end E2E evidence check ---------------------------------------------------
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
node --test tools/test/check-gates.test.mjs
```
Expected: all 8 tests PASS.

- [ ] **Step 5: Regression — the full suite still passes**

Run:
```bash
npm run test:tools
```
Expected: all existing tests + the new file pass.

- [ ] **Step 6: Commit**

```bash
git add src/shared/scripts/check-gates.sh tools/test/check-gates.test.mjs
git commit -m "feat(gates): bind E2E verified box to a fresh PASS report (sh)"
```

---

### Task 3: `check-gates.ps1` parity (TDD)

**Files:**
- Create: `tools/test/check-gates.ps1.test.mjs`
- Modify: `src/shared/scripts/check-gates.ps1` (insert before the final `Write-Output`/`exit 0` at `:77`)

**Interfaces:**
- Consumes: marker from Task 1; must produce the identical exit codes as Task 2's `check-gates.sh`.

- [ ] **Step 1: Write the failing parity test**

Create `tools/test/check-gates.ps1.test.mjs` — same fixtures as Task 2 but invoking `pwsh`, skipped when `pwsh` is absent:
```javascript
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const script = join(repoRoot, 'src', 'shared', 'scripts', 'check-gates.ps1');

let hasPwsh = true;
try { execFileSync('pwsh', ['-v'], { stdio: 'pipe' }); } catch { hasPwsh = false; }

function git(cwd, ...args) { execFileSync('git', args, { cwd, stdio: 'pipe' }); }

function make(box, report) {
  const dir = mkdtempSync(join(tmpdir(), 'cgps-'));
  git(dir, 'init', '-q', '-b', 'main');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  writeFileSync(join(dir, 'seed'), 'x'); git(dir, 'add', '.'); git(dir, 'commit', '-qm', 's');
  git(dir, 'checkout', '-q', '-b', 'feat/x');
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'),
`## Active workflow
- **Profile:** standard
## Ship-gate checklist
- [x] a
- [x] b
- [x] c
- [x] d
${box}
- [x] f
`);
  if (report !== undefined) {
    mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
    writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'r.md'), report);
  }
  return dir;
}
function run(dir) {
  try { execFileSync('pwsh', [script, '.workflow/state.md'], { cwd: dir, stdio: 'pipe' }); return 0; }
  catch (e) { return e.status; }
}

test('ps1 parity: fresh PASS → 0, missing → 1, FAIL → 1, empty N/A → 1', { skip: !hasPwsh }, () => {
  const box = '- [x] E2E verified via verify-e2e (report: docs/e2e/reports/r.md)';
  let d = make(box, 'VERDICT: PASS\n'); assert.equal(run(d), 0); rmSync(d, { recursive: true, force: true });
  d = make(box, undefined);            assert.equal(run(d), 1); rmSync(d, { recursive: true, force: true });
  d = make(box, 'VERDICT: FAIL\n');    assert.equal(run(d), 1); rmSync(d, { recursive: true, force: true });
  d = make('- [x] E2E verified — N/A:', undefined); assert.equal(run(d), 1); rmSync(d, { recursive: true, force: true });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
node --test tools/test/check-gates.ps1.test.mjs
```
Expected: FAIL (if `pwsh` present) — the ps1 ignores the E2E marker. If `pwsh` absent: test is skipped (that's acceptable locally; Windows CI enforces it).

- [ ] **Step 3: Implement the E2E check in `check-gates.ps1`**

In `src/shared/scripts/check-gates.ps1`, insert **before** line 77 (`Write-Output "check-gates: profile ..."`):
```powershell
# --- E2E evidence check (Attested) --------------------------------------------
$e2eLine = $null
$inE = $false
foreach ($line in $lines) {
    if ($line -match '^##\s+Ship-gate checklist') { $inE = $true; continue }
    elseif ($line -match '^##\s')                 { $inE = $false }
    if ($inE -and $line -match '^- \[[xX]\]\s+E2E verified') { $e2eLine = $line; break }
}
if ($e2eLine) {
    if ($e2eLine -match 'N/A:') {
        $reason = ([regex]::Match($e2eLine, 'N/A:\s*(.*)$')).Groups[1].Value.Trim()
        if ([string]::IsNullOrEmpty($reason)) {
            [Console]::Error.WriteLine("check-gates: 'E2E verified' uses 'N/A:' with no reason — treated as unmet.")
            exit 1
        }
    } else {
        $inRepo = $false
        try { git rev-parse --is-inside-work-tree *> $null; if ($LASTEXITCODE -eq 0) { $inRepo = $true } } catch {}
        if ($inRepo) {
            $default = ''
            foreach ($b in 'main','master') {
                git show-ref --verify --quiet "refs/heads/$b" *> $null
                if ($LASTEXITCODE -eq 0) { $default = $b; break }
            }
            $current = (git rev-parse --abbrev-ref HEAD 2>$null)
            $base = ''
            if ($default -and $current -ne $default) { $base = (git merge-base HEAD $default 2>$null) }
            if ($base) {
                $changed   = (git diff --name-only "$base..HEAD" -- docs/e2e/reports/ 2>$null)
                $untracked = (git ls-files --others --exclude-standard -- docs/e2e/reports/ 2>$null)
                $cands = @($changed) + @($untracked) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
                $found = $false
                foreach ($f in $cands) {
                    if ((Get-Content -LiteralPath $f) -match '^VERDICT:\s*PASS(\s|$)') { $found = $true; break }
                }
                if (-not $found) {
                    [Console]::Error.WriteLine("check-gates: 'E2E verified' is checked, but no report in docs/e2e/reports/ is")
                    [Console]::Error.WriteLine("  both changed on this branch (since $default) and 'VERDICT: PASS'.")
                    [Console]::Error.WriteLine("  Run the verify-e2e skill, or use '-- N/A: <reason>' for internal/UI-only changes.")
                    exit 1
                }
            }
        }
    }
}
# --- end E2E evidence check ---------------------------------------------------
```

- [ ] **Step 4: Run the parity test to verify it passes**

Run:
```bash
node --test tools/test/check-gates.ps1.test.mjs
```
Expected: PASS (or skipped if no `pwsh`).

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/check-gates.ps1 tools/test/check-gates.ps1.test.mjs
git commit -m "feat(gates): E2E verified evidence check — PowerShell parity"
```

---

### Task 4: The `verify-e2e` SKILL.md + index registration

**Files:**
- Create: `src/skills/verify-e2e/SKILL.md`
- Modify: `src/CLAUDE.md` (skill index list)

**Interfaces:**
- Consumes: gate marker (Task 1), report path convention `docs/e2e/reports/<YYYY-MM-DD>-<feature>.md`.
- Produces: the skill discovered by the linter and all three engines.

- [ ] **Step 1: Write the skill**

Create `src/skills/verify-e2e/SKILL.md`:
````markdown
---
name: verify-e2e
description: Execute user-journey use cases (API and CLI in v1) against the running app, classify each, and write a committed evidence report the ship-gate binds to. Use to verify a user-facing change end to end before shipping, under Claude Code, Codex, or OpenCode.
---

# verify-e2e

Run **user journeys** — not unit tests — against real interfaces, then bind the result to
the ship-gate with an evidence report. API and CLI are executed in v1; UI is deferred
(record `E2E verified — N/A: UI journey, no v1 adapter`). The driver runs this; it is not a
cross-engine review.

## 0. Locate use cases

From the active plan (`new-feature` / `fix-bug`) or, in regression mode, from
`docs/e2e/use-cases/*.md`.

## 1. Validate journey shape (before executing)

Each use case MUST carry: **ID, Actor, Scenario, Interface (API|CLI), Intent, Setup, Steps
(≥2), Verification, Persistence**. Reject a malformed UC with a reason code and stop —
rewrite it, don't execute it:

- `MISSING_ACTOR` · `MISSING_SCENARIO` · `SCENARIO_FLUFF` · `CHEAT_SETUP` (Setup performs the
  action under test) · `THIN_VERIFICATION` (bare status/exit code) · `MISSING_PERSISTENCE` ·
  `TOO_SHALLOW` (<2 meaningful steps) · `NOT_USER_JOURNEY` (reads as a unit/contract test) ·
  `WRONG_INTERFACE`.

## 2. ARRANGE — sanctioned setup only

Public API, signup/login, app CLI, or documented seed commands. **Forbidden:** raw DB writes
(`psql -c "INSERT"`, `mysql -e`, `mongosh --eval`), internal/undocumented endpoints,
file-injection on disk. If the sanctioned path is broken, **fix it** — never route around it.
Credentials come from **env vars**, never hard-coded (graduated use cases are committed).

## 3. Safety

- Default to a **non-production** target; require explicit confirmation otherwise.
- **Redact** secrets/tokens/PII from captured output before writing the report.
- Quote/escape UC-provided values; never `eval` raw UC text.
- Clean up resources you created, or note residual state in the report.

## 4. ACT + VERIFY per interface

- **API** — `curl`/`httpie`: assert status, body, headers, AND a follow-up request (e.g. GET
  the resource a POST created via its `Location`).
- **CLI** — subprocess: assert stdout/stderr + exit code, AND a second invocation that
  observes the persisted state (e.g. `add` then `list`).

No cheating in VERIFY: assert only through the interface under test.

## 5. Classify + verdict

| Result | Blocks ship? | Retry |
| --- | --- | --- |
| `PASS` | no | — |
| `FAIL_BUG` | yes | no |
| `FAIL_STALE` (UC references a renamed interface) | yes, until UC updated | no |
| `FAIL_INFRA` (server down/timeout) | yes if still failing after 1 retry | once |
| `FAIL_INVALID_UC` | yes | no |

**Top-level `VERDICT: PASS` only if every required UC is `PASS`.** Anything else →
`VERDICT: FAIL`.

## 6. Write the evidence report

`docs/e2e/reports/<YYYY-MM-DD>-<feature>.md` (committed). Include a header line
(feature, branch, ISO-8601 timestamp), the top-level `VERDICT: PASS|FAIL`, and one block per
UC (ID, classification, interface, trimmed+redacted output, persistence re-check).

## 7. Graduate passing use cases

Upsert each `PASS` UC by its **ID** into `docs/e2e/use-cases/<feature>.md` so later sessions
re-run it. Then check the `E2E verified` ship-gate box (or record `— N/A: <reason>`).

## Common rationalizations

| Rationalization | Reality |
| --- | --- |
| "Tests pass, that's enough." | Unit tests miss wiring/integration/UX. A journey exercises the real interface. |
| "I'll assert the status code and move on." | A bare 200/exit-0 is `THIN_VERIFICATION`. Observe a real outcome + a next observable step. |
| "I'll seed the row straight into the DB." | Raw DB writes are forbidden ARRANGE. Use the sanctioned interface, or fix it. |
| "Just check the box — the report can wait." | `check-gates` binds the box to a fresh `VERDICT: PASS` report; an empty claim fails the gate. |
| "It's a read endpoint, skip Persistence." | Only genuinely stateless reads may use `Persistence: N/A`. |

## Red flags

- A use case with no Actor/Scenario, or an Intent naming endpoints/tables/components.
- Setup that performs the very action the UC is meant to test.
- Checking the `E2E verified` box without a committed `VERDICT: PASS` report on this branch.
- Verifying through a back channel (DB/logs) instead of the interface under test.

## Verification

- [ ] Every use case validated for shape before execution.
- [ ] API/CLI journeys executed; VERIFY only through the interface under test.
- [ ] Report written to `docs/e2e/reports/` with a top-level verdict; secrets redacted.
- [ ] Passing UCs graduated to `docs/e2e/use-cases/<feature>.md` by ID.
- [ ] `E2E verified` gate box checked only with a fresh `VERDICT: PASS` report (or `N/A:`).
````

- [ ] **Step 2: Register in the skill index**

In `src/CLAUDE.md`, under `## Workflow skills (...)`, add this line after the `simplify` entry:
```markdown
- `verify-e2e` — execute API/CLI user-journey use cases, write an evidence report, and bind the E2E ship-gate box to it
```

- [ ] **Step 3: Run the linter**

Run:
```bash
npm run lint:skills
```
Expected: PASS — `14 entries checked — 0 error(s) — PASSED` (13 existing + verify-e2e; index parity satisfied by Step 2).

- [ ] **Step 4: Commit**

```bash
git add src/skills/verify-e2e/SKILL.md src/CLAUDE.md
git commit -m "feat(skill): add verify-e2e skill + register in index"
```

---

### Task 5: Routing eval cases (positives + negatives) — REQUIRED

`tools/run-evals.mjs` enforces **coverage**: every skill in `src/skills/` must have an entry
in the `skills` object of `routing-cases.json`. So after Task 4 created the skill dir, the
eval fails until this entry exists — this task is mandatory, not polish.

**Files:**
- Modify: `tools/evals/routing-cases.json`

**Interfaces:**
- Consumes: the `verify-e2e` description from Task 4 (drives routing).
- Schema (confirmed): top-level object `{ "_comment": ..., "skills": { "<skill>": { "positive": [string], "negative": [{ "prompt": string, "owner": string }] } } }`. `positive` = asks that MUST rank `verify-e2e` in the top-k; `negative` = a sibling's ask where the sibling `owner` MUST outrank `verify-e2e`. Paraphrase how users talk — never copy the description text.

- [ ] **Step 1: Add the `verify-e2e` entry**

In `tools/evals/routing-cases.json`, inside the `"skills"` object, add:
```json
"verify-e2e": {
  "positive": [
    "run the user journeys against the API and confirm the evidence report passes",
    "exercise the checkout use cases through the real interface and re-check they persist",
    "drive the order-creation flow via the CLI as a user would and confirm the outcome"
  ],
  "negative": [
    { "prompt": "wrap up the branch and open the pull request", "owner": "finish-branch" },
    { "prompt": "build the CSV export feature end to end with tests and review", "owner": "new-feature" },
    { "prompt": "give me a second opinion on this diff and flag any bugs", "owner": "review" }
  ]
}
```

- [ ] **Step 2: Add a defensive negative to siblings most likely to collide**

To `new-feature.negative` and `finish-branch.negative`, add one prompt each that MUST route
to `verify-e2e`, asserting the sibling does not swallow it:
```json
{ "prompt": "run the end-to-end user journeys and write the evidence report", "owner": "verify-e2e" }
```

- [ ] **Step 3: Run the routing eval**

Run:
```bash
npm run eval:routing
```
Expected: PASS, rank-1 above floor, **0 collisions ≥0.75**. If `verify-e2e` collides with `finish-branch`/`new-feature`, sharpen the `verify-e2e` description in `src/skills/verify-e2e/SKILL.md` (lead with "execute … use cases … evidence report" and avoid the words "finish"/"end to end ship") and re-run.

- [ ] **Step 4: Commit**

```bash
git add tools/evals/routing-cases.json src/skills/verify-e2e/SKILL.md
git commit -m "test(routing): add verify-e2e positives + negatives"
```

---

### Task 6: Scaffold `docs/e2e/` (source + both installers)

**Files:**
- Create: `src/docs/e2e/reports/.gitkeep`, `src/docs/e2e/use-cases/.gitkeep`
- Modify: `src/shared/rules/docs-layout.md`
- Modify: `install.sh:181`, `install.ps1:172`

**Interfaces:**
- Produces: `docs/e2e/{reports,use-cases}` present in every target install (so the gate's report path exists).

- [ ] **Step 1: Create source scaffold seeds**

```bash
mkdir -p src/docs/e2e/reports src/docs/e2e/use-cases
: > src/docs/e2e/reports/.gitkeep
: > src/docs/e2e/use-cases/.gitkeep
```

- [ ] **Step 2: Register in docs-layout.md**

In `src/shared/rules/docs-layout.md`, add a row/line documenting:
```markdown
- `docs/e2e/reports/` — verify-e2e evidence reports (committed; the ship-gate binds to these)
- `docs/e2e/use-cases/` — graduated user-journey use cases (committed regression suite)
```

- [ ] **Step 3: Extend the installer docs-dir scaffold (bash)**

The `docs/` scaffold loop (`install.sh:181-184`) uses `$TARGET` and creates a `.gitkeep` in
each dir. `mkdir -p` already handles nesting, so simply add the two nested paths to the loop
list. Change `install.sh:181` from:
```sh
for d in prds plans research solutions adr; do
```
to:
```sh
for d in prds plans research solutions adr e2e/reports e2e/use-cases; do
```
(The loop body `mkdir -p "$TARGET/docs/$d"` + `.gitkeep` at `:182-183` then creates
`docs/e2e/reports/.gitkeep` and `docs/e2e/use-cases/.gitkeep` unchanged.)

- [ ] **Step 4: Extend the installer docs-dir scaffold (PowerShell)**

The parity loop (`install.ps1:172-177`) uses `$Target` and `Join-Path $Target "docs/$d"`
(PS7 Join-Path accepts the forward slash and `New-Item -Force` creates nested dirs). Change
`install.ps1:172` from:
```powershell
foreach ($d in 'prds', 'plans', 'research', 'solutions', 'adr') {
```
to:
```powershell
foreach ($d in 'prds', 'plans', 'research', 'solutions', 'adr', 'e2e/reports', 'e2e/use-cases') {
```

- [ ] **Step 5: Verify via a dry-run install**

Run (into a throwaway dir):
```bash
tmp=$(mktemp -d); ./install.sh "$tmp" --git-init >/dev/null 2>&1; ls -d "$tmp/docs/e2e/reports" "$tmp/docs/e2e/use-cases" && echo OK; rm -rf "$tmp"
```
Expected: both paths listed, `OK`.

- [ ] **Step 6: Add/extend an installer smoke assertion**

If `tests/smoke.sh` (or the installer's post-install validation) asserts scaffolded dirs, add `docs/e2e/reports` and `docs/e2e/use-cases` to that assertion list. Run:
```bash
sh tests/smoke.sh
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add src/docs/e2e install.sh install.ps1 src/shared/rules/docs-layout.md tests/smoke.sh
git commit -m "feat(install): scaffold docs/e2e/{reports,use-cases} into targets"
```

---

### Task 7: Wire the skill into the workflow skills

**Files:**
- Modify: `src/skills/new-feature/SKILL.md` (step 6)
- Modify: `src/skills/fix-bug/SKILL.md` (verify step — add, don't replace)
- Modify: `src/skills/finish-branch/SKILL.md` (note the gate)
- Modify: `src/docs/extending.md` (v2 notes)

- [ ] **Step 1: new-feature verify step**

In `src/skills/new-feature/SKILL.md` step 6 ("Verify"), replace the free-text "actually exercise the change" instruction with:
```markdown
Run the `verify-e2e` skill: design/execute API & CLI user-journey use cases, and let it
write the evidence report the ship-gate checks. For purely internal or UI-only changes,
record `E2E verified — N/A: <reason>` in `.workflow/state.md`.
```

- [ ] **Step 2: fix-bug verify step (add, keep existing)**

In `src/skills/fix-bug/SKILL.md`, in the verify step, **keep** the existing original-repro and neighbor checks and ADD:
```markdown
Then run the `verify-e2e` skill to confirm the fix through the user-facing interface
(API/CLI). Internal-only fixes record `E2E verified — N/A: <reason>`.
```

- [ ] **Step 3: finish-branch note**

In `src/skills/finish-branch/SKILL.md`, near the gate-confirmation step, add:
```markdown
`check-gates` now also enforces the `E2E verified` marker — if it's checked (not `N/A:`),
a fresh `VERDICT: PASS` report must exist under `docs/e2e/reports/`. finish-branch relies on
the report produced during the workflow; it does not re-run the journeys.
```

- [ ] **Step 4: extending.md v2 notes**

In `src/docs/extending.md`, add a short "verify-e2e roadmap (v2)" note: Playwright `.spec.ts`
regression bridge, a UI interface adapter, and the automatic multi-surface (UI/API/CLI)
coverage audit — each a skill/config extension, no hooks.

- [ ] **Step 5: Full check**

Run:
```bash
npm run check
```
Expected: `lint:skills`, `eval:routing`, and `test:tools` all PASS.

- [ ] **Step 6: Commit**

```bash
git add src/skills/new-feature/SKILL.md src/skills/fix-bug/SKILL.md src/skills/finish-branch/SKILL.md src/docs/extending.md
git commit -m "feat(workflow): wire verify-e2e into new-feature, fix-bug, finish-branch"
```

---

## Self-review checklist (run before handoff)

- [ ] **Spec coverage:** every spec section maps to a task — schema→T4, skill flow/safety/adapters→T4, classification→T4, evidence report→T4, gate integration→T1+T2+T3, wiring→T7, files touched→T1-T7, testing→T2/T3/T5/T6.
- [ ] **Marker string identical** across ship-gates.md, state.template.md, check-gates.sh, check-gates.ps1, and the tests: `E2E verified`.
- [ ] **sh and ps1 exit codes match** for all fixtures (verified by T2 + T3).
- [ ] **No placeholders** — every code step shows real code; installer vars confirmed (`$TARGET` at `install.sh:181-184`, `$Target` at `install.ps1:172-177`).
- [ ] `standard` profile count stays 6 (T1 Step 4).

## Notes for the implementer

- `check-gates.sh` uses `set -eu`; the new block is invoked in normal flow and each git call
  is guarded with `|| echo ""`, so a missing branch/merge-base degrades to skip, not abort.
- Filenames under `docs/e2e/reports/` follow `YYYY-MM-DD-<slug>.md` (no spaces) — the `for f in
  $changed $untracked` word-split is safe for that convention.
- The routing description in the SKILL frontmatter is load-bearing for T5; if the eval flags a
  collision, tune the description, not the eval threshold.
