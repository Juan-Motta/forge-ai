# /goal Plan A — state + digest helper (foundation) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the two engine-neutral shell helpers `/goal` relies on — `goal-digest.{sh,ps1}`
(the §6.1 certification digest) and `goal-state.{sh,ps1}` (read `## /goal loop` fields, count the
convergence-breaker rounds, and read/bump the durable ship-red attempt counter) — with node tests.

**Architecture:** These ship to target repos, so they are POSIX `sh` + PowerShell (no Node runtime
in targets), exactly like the existing `src/shared/scripts/check-gates.{sh,ps1}`. Dev-only tests
live in `tools/test/*.test.mjs` (`node --test`, zero-dep) and **spawn** the scripts, mirroring
`tools/test/check-gates.test.mjs`. The digest is computed from `git diff <base_sha>` for tracked
changes plus framed content of untracked non-ignored files, minus a fixed exclusion set — proven
deterministic against a throwaway git repo in the tests.

**Tech Stack:** POSIX `sh`, PowerShell 7 (`pwsh`), `git`, `shasum`/`sha256sum`, `node:test`,
`node:child_process`, `node:fs`, `node:os`.

## Global Constraints (from the design spec, verbatim values)

- Digest exclusion set (§6.1), applied to BOTH the tracked diff pathspecs AND the untracked scan:
  `.workflow/*`, `docs/e2e/reports/*`, `CONTINUITY.md`, `docs/CHANGELOG.md`, `VERSION`.
  **`package.json`/lockfiles are NOT excluded** (feature content).
- Digest determinism: `LC_ALL=C`, `git diff --no-renames --no-color`, untracked files sorted.
- Digest framing: each untracked entry carries `path + mode + length + content` so a rename /
  empty-file add / content repartition changes the digest.
- Breaker constants (consumed by callers, not hard-coded in the helper): `N=4`,
  `MAX_REENTRIES=3`, `MAX_CODE_ROUNDS=3·N`. The helper only *counts*; callers compare.
- Review-log line schema (§10): `- loop=plan|code — round=<N> — kind=round|recert|cert —
  reviewer=<engine|self> — result=clean|P0=a/P1=b/P2=c — digest — ts`. Breaker counts `kind=round`.
- Ship-red attempt schema (§10): `- ATTEMPT ship-red — n=<k> — ts` in `## Attempts`; `n>=2` → HALT.
- sh/ps1 parity is mandatory (this project's past bugs all lived in sh↔ps1 drift); Task 3 and
  Task 6 assert byte-identical output across the two implementations for the same repo state.
- Scripts must be safe under `set -eu` and `set -f` (noglob — pathspecs contain `*`); no POSIX
  `\b`; portable `sha256` (prefer `sha256sum`, fall back to `shasum -a 256`).

---

## File Structure

- `src/shared/scripts/goal-digest.sh` — `sh goal-digest.sh <base_sha> [repo_dir]` → prints the
  64-char hex digest of the current worktree's in-scope content vs `base_sha`.
- `src/shared/scripts/goal-digest.ps1` — PowerShell twin, byte-identical output.
- `src/shared/scripts/goal-state.sh` — `sh goal-state.sh <subcommand> …` (`field`, `round-count`,
  `ship-red-count`, `ship-red-bump`).
- `src/shared/scripts/goal-state.ps1` — PowerShell twin.
- `tools/test/goal-digest.test.mjs` — spawns `goal-digest.sh`, asserts determinism / framing /
  exclusions against a throwaway git repo.
- `tools/test/goal-digest.ps1.test.mjs` — parity: `goal-digest.ps1` == `goal-digest.sh` (skips if
  `pwsh` absent, like `check-gates.ps1.test.mjs`).
- `tools/test/goal-state.test.mjs` — spawns `goal-state.sh`, asserts each subcommand.
- `tools/test/goal-state.ps1.test.mjs` — parity for `goal-state.ps1`.

Tasks 1–3 deliver the digest helper; Tasks 4–6 the state helper. Each ends with a green test run
and a commit.

---

### Task 1: `goal-digest.sh` — tracked-change digest vs base

**Files:**
- Create: `src/shared/scripts/goal-digest.sh`
- Test: `tools/test/goal-digest.test.mjs`

**Interfaces:**
- Consumes: nothing (leaf).
- Produces: `goal-digest.sh <base_sha> [repo_dir]` → stdout: one line, 64-char lowercase hex.
  Exit 0 on success; exit 3 if `git`/sha tool missing or `base_sha` empty.

- [ ] **Step 1: Write the failing test**

Create `tools/test/goal-digest.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const SH = new URL('../../src/shared/scripts/goal-digest.sh', import.meta.url).pathname;

function initRepo() {
  const dir = mkdtempSync(join(tmpdir(), 'goaldig-'));
  const git = (...a) => execFileSync('git', a, { cwd: dir, stdio: 'pipe' });
  git('init', '-q');
  git('config', 'user.email', 't@t.co');
  git('config', 'user.name', 'T');
  writeFileSync(join(dir, 'seed.txt'), 'seed\n');
  git('add', '.'); git('commit', '-qm', 'base');
  const base = git('rev-parse', 'HEAD').toString().trim();
  return { dir, base, git };
}
const digest = (dir, base) =>
  execFileSync('sh', [SH, base, dir], { cwd: dir }).toString().trim();

test('digest is 64-char hex and deterministic', () => {
  const { dir, base, git } = initRepo();
  writeFileSync(join(dir, 'seed.txt'), 'seed\nchanged\n'); // tracked modification
  git('add', 'seed.txt');
  const d1 = digest(dir, base);
  const d2 = digest(dir, base);
  assert.match(d1, /^[0-9a-f]{64}$/);
  assert.equal(d1, d2);
});

test('a tracked content change moves the digest', () => {
  const { dir, base } = initRepo();
  const before = digest(dir, base);               // clean worktree vs base
  writeFileSync(join(dir, 'seed.txt'), 'seed\nX\n');
  const after = digest(dir, base);
  assert.notEqual(before, after);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `node --test tools/test/goal-digest.test.mjs`
Expected: FAIL — `goal-digest.sh` does not exist (spawn ENOENT).

- [ ] **Step 3: Write the minimal implementation**

Create `src/shared/scripts/goal-digest.sh`:

```sh
#!/bin/sh
# goal-digest.sh — /goal certification digest (design §6.1).
# Usage: sh goal-digest.sh <base_sha> [repo_dir]
# Prints a 64-char hex digest of the worktree's in-scope content vs <base_sha>:
# tracked changes (git diff vs base) + framed untracked non-ignored files, minus
# a fixed exclusion set. Deterministic (LC_ALL=C, --no-renames, sorted untracked).
# Exit: 0 ok · 3 bad args / missing tool.
set -eu
LC_ALL=C; export LC_ALL

base="${1:-}"
[ -n "$base" ] || { echo "goal-digest: missing base_sha" >&2; exit 3; }
repo="${2:-.}"
cd "$repo" || { echo "goal-digest: bad repo dir" >&2; exit 3; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1; fi
}

set -f  # noglob: exclusion pathspecs contain '*'
# exclusion set — keep in sync with design §6.1 and goal-digest.ps1
set -- \
  ':(exclude).workflow/*' \
  ':(exclude)docs/e2e/reports/*' \
  ':(exclude)CONTINUITY.md' \
  ':(exclude)docs/CHANGELOG.md' \
  ':(exclude)VERSION'
# "$base" saved above; "$@" is now the exclusion pathspec list.

{
  # (a) tracked changes vs base
  git -c core.quotepath=false diff --no-renames --no-color "$base" -- . "$@"
  # (b) framed untracked non-ignored files (Task 2 fills this in)
} | sha256
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test tools/test/goal-digest.test.mjs`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-digest.sh tools/test/goal-digest.test.mjs
git commit -m "feat(goal): goal-digest.sh tracked-change certification digest"
```

---

### Task 2: `goal-digest.sh` — untracked framing + exclusions

**Files:**
- Modify: `src/shared/scripts/goal-digest.sh` (the `# (b)` block)
- Test: `tools/test/goal-digest.test.mjs` (add cases)

**Interfaces:**
- Produces: same signature; digest now also binds untracked non-ignored files with
  `path + mode + length + content` framing, and honors the exclusion set on both clauses.

- [ ] **Step 1: Write the failing tests**

Append to `tools/test/goal-digest.test.mjs`:

```js
test('an untracked non-ignored file (incl. empty) is bound', () => {
  const { dir, base } = initRepo();
  const before = digest(dir, base);
  writeFileSync(join(dir, 'new-empty.txt'), '');   // empty untracked add
  const after = digest(dir, base);
  assert.notEqual(before, after);                   // framing binds path+length even at len 0
});

test('an excluded path does NOT move the digest', () => {
  const { dir, base } = initRepo();
  const before = digest(dir, base);
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'), 'loop noise\n');
  writeFileSync(join(dir, 'docs'), '', { flag: 'a' }); // ensure docs path exists is not needed
  const after = digest(dir, base);
  assert.equal(before, after);                      // .workflow/* excluded on the untracked scan
});

test('a rename moves the digest (--no-renames = delete+add)', () => {
  const { dir, base, git } = initRepo();
  const before = digest(dir, base);
  git('mv', 'seed.txt', 'renamed.txt');
  const after = digest(dir, base);
  assert.notEqual(before, after);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test tools/test/goal-digest.test.mjs`
Expected: the empty-untracked test FAILS (untracked not yet hashed).

- [ ] **Step 3: Fill in the untracked framing block**

Replace the `# (b) framed untracked...` comment line in `goal-digest.sh` with:

```sh
  # (b) framed untracked non-ignored files (sorted, NUL-safe)
  git ls-files -z --others --exclude-standard -- . "$@" \
    | LC_ALL=C sort -z \
    | while IFS= read -r d -d '' f; do
        # 'read -d' is not POSIX; use a portable NUL reader below instead.
        :
      done
```

That `read -d` is non-POSIX — replace the whole block with this portable NUL reader:

```sh
  # (b) framed untracked non-ignored files (sorted, NUL-safe, POSIX)
  git ls-files -z --others --exclude-standard -- . "$@" | LC_ALL=C sort -z | tr '\0' '\n' \
  | while IFS= read -r f; do
        [ -n "$f" ] || continue
        if [ -x "$f" ]; then mode=100755; else mode=100644; fi
        len=$(wc -c < "$f" | tr -d ' ')
        printf 'U\t%s\t%s\t%s\n' "$f" "$mode" "$len"
        cat "$f"
        printf '\n\036\n'   # record separator (RS)
      done
```

(Filenames with embedded newlines are out of scope for v1 — codeforge repos don't use them; the
`sort -z | tr '\0' '\n'` keeps NUL-sorting deterministic while staying POSIX.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test tools/test/goal-digest.test.mjs`
Expected: PASS (all five tests).

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-digest.sh tools/test/goal-digest.test.mjs
git commit -m "feat(goal): goal-digest.sh untracked framing + exclusion set"
```

---

### Task 3: `goal-digest.ps1` — PowerShell parity

**Files:**
- Create: `src/shared/scripts/goal-digest.ps1`
- Test: `tools/test/goal-digest.ps1.test.mjs`

**Interfaces:**
- Produces: `pwsh goal-digest.ps1 <base_sha> [repo_dir]` → identical 64-char hex to the `.sh` for
  the same repo state.

- [ ] **Step 1: Write the failing parity test**

Create `tools/test/goal-digest.ps1.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const SH  = new URL('../../src/shared/scripts/goal-digest.sh',  import.meta.url).pathname;
const PS1 = new URL('../../src/shared/scripts/goal-digest.ps1', import.meta.url).pathname;
const hasPwsh = spawnSync('pwsh', ['-v'], { stdio: 'ignore' }).status === 0;

test('goal-digest.ps1 == goal-digest.sh for the same worktree', { skip: !hasPwsh }, () => {
  const dir = mkdtempSync(join(tmpdir(), 'goaldigp-'));
  const git = (...a) => execFileSync('git', a, { cwd: dir, stdio: 'pipe' });
  git('init', '-q'); git('config', 'user.email', 't@t.co'); git('config', 'user.name', 'T');
  writeFileSync(join(dir, 'seed.txt'), 'seed\n'); git('add', '.'); git('commit', '-qm', 'base');
  const base = git('rev-parse', 'HEAD').toString().trim();
  writeFileSync(join(dir, 'seed.txt'), 'seed\nchanged\n');
  writeFileSync(join(dir, 'extra.txt'), 'untracked\n');
  const sh  = execFileSync('sh',   [SH,  base, dir], { cwd: dir }).toString().trim();
  const ps1 = execFileSync('pwsh', ['-NoProfile', '-File', PS1, base, dir], { cwd: dir }).toString().trim();
  assert.equal(ps1, sh);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `node --test tools/test/goal-digest.ps1.test.mjs`
Expected: FAIL (ps1 missing) — or SKIP if `pwsh` absent (then verify on a machine with pwsh / CI).

- [ ] **Step 3: Write the PowerShell twin**

Create `src/shared/scripts/goal-digest.ps1`:

```powershell
#!/usr/bin/env pwsh
# goal-digest.ps1 — PowerShell twin of goal-digest.sh (design §6.1). Byte-identical output.
param([Parameter(Mandatory)][string]$Base, [string]$RepoDir = '.')
$ErrorActionPreference = 'Stop'
Set-Location $RepoDir
$env:LC_ALL = 'C'
$excl = @(':(exclude).workflow/*', ':(exclude)docs/e2e/reports/*', ':(exclude)CONTINUITY.md',
          ':(exclude)docs/CHANGELOG.md', ':(exclude)VERSION')

# Build the same byte stream the .sh pipes to sha256, then hash it.
$sha = [System.Security.Cryptography.SHA256]::Create()
$ms  = New-Object System.IO.MemoryStream
$w   = New-Object System.IO.StreamWriter($ms)
$w.NewLine = "`n"

# (a) tracked diff vs base
$diff = & git -c core.quotepath=false diff --no-renames --no-color $Base -- . @excl
foreach ($line in $diff) { $w.Write($line); $w.Write("`n") }

# (b) framed untracked non-ignored files, sorted
$others = (& git ls-files -z --others --exclude-standard -- . @excl) -split "`0" |
          Where-Object { $_ -ne '' } | Sort-Object -Culture ([System.Globalization.CultureInfo]::InvariantCulture)
foreach ($f in $others) {
  $mode = if ((Get-Item $f).UnixMode -match 'x') { '100755' } else { '100644' }
  $bytes = [System.IO.File]::ReadAllBytes($f)
  $w.Write("U`t$f`t$mode`t$($bytes.Length)`n")
  $w.Flush(); $ms.Write($bytes, 0, $bytes.Length)
  $w.Write("`n`u{001e}`n")
}
$w.Flush()
$hash = $sha.ComputeHash($ms.ToArray())
-join ($hash | ForEach-Object { $_.ToString('x2') })
```

- [ ] **Step 4: Run to verify parity passes**

Run: `node --test tools/test/goal-digest.ps1.test.mjs`
Expected: PASS on a machine with `pwsh` (CI's windows job runs this — see Task 7 note). If the
byte stream differs, reconcile the `.sh` and `.ps1` framing until the digests match; the test is
the arbiter.

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-digest.ps1 tools/test/goal-digest.ps1.test.mjs
git commit -m "feat(goal): goal-digest.ps1 PowerShell parity"
```

---

### Task 4: `goal-state.sh` — field / round-count / ship-red subcommands

**Files:**
- Create: `src/shared/scripts/goal-state.sh`
- Test: `tools/test/goal-state.test.mjs`

**Interfaces:**
- Produces:
  - `goal-state.sh field <name> [state.md]` → the `## /goal loop` field value (e.g. `phase`), or empty.
  - `goal-state.sh round-count <plan|code> [state.md]` → integer count of `## Review log` lines with
    `loop=<x>` AND `kind=round` (the breaker count).
  - `goal-state.sh ship-red-count [state.md]` → the latest `n` from `## Attempts` `ATTEMPT ship-red`
    lines, or `0`.
  - Exit 0 always for reads (missing file → empty/`0`); exit 3 on unknown subcommand.

- [ ] **Step 1: Write the failing tests**

Create `tools/test/goal-state.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const SH = new URL('../../src/shared/scripts/goal-state.sh', import.meta.url).pathname;
const run = (args, cwd) => execFileSync('sh', [SH, ...args], { cwd }).toString().trim();

function stateFile(body) {
  const dir = mkdtempSync(join(tmpdir(), 'goalst-'));
  writeFileSync(join(dir, 'state.md'), body);
  return dir;
}
const STATE = `## /goal loop
| Field | Value |
| ----- | ----- |
| phase | code-review |
| reentries | 2 |

## Review log
- loop=code — round=1 — kind=round — reviewer=codex — result=P1=1 — digest=aa — ts=t1
- loop=code — round=2 — kind=round — reviewer=self — result=clean — digest=bb — ts=t2
- loop=code — round=3 — kind=cert — reviewer=codex — result=clean — digest=bb — ts=t3
- loop=plan — round=1 — kind=round — reviewer=codex — result=clean — digest=cc — ts=t0

## Attempts
- ATTEMPT ship-red — n=1 — ts=t4
`;

test('field reads a ## /goal loop value', () => {
  const dir = stateFile(STATE);
  assert.equal(run(['field', 'phase', 'state.md'], dir), 'code-review');
  assert.equal(run(['field', 'reentries', 'state.md'], dir), '2');
});

test('round-count counts kind=round for the loop only', () => {
  const dir = stateFile(STATE);
  assert.equal(run(['round-count', 'code', 'state.md'], dir), '2'); // cert line excluded
  assert.equal(run(['round-count', 'plan', 'state.md'], dir), '1');
});

test('ship-red-count returns the latest n, or 0 when absent', () => {
  const dir = stateFile(STATE);
  assert.equal(run(['ship-red-count', 'state.md'], dir), '1');
  const empty = stateFile('## /goal loop\n');
  assert.equal(run(['ship-red-count', 'state.md'], empty), '0');
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `node --test tools/test/goal-state.test.mjs`
Expected: FAIL (script missing).

- [ ] **Step 3: Write the implementation**

Create `src/shared/scripts/goal-state.sh`:

```sh
#!/bin/sh
# goal-state.sh — read helpers for /goal's .workflow/state.md (design §4, §6.2, §10).
# Subcommands:
#   field <name> [state.md]        value of a '## /goal loop' table field
#   round-count <plan|code> [file] # of '## Review log' lines with loop=<x> AND kind=round
#   ship-red-count [state.md]      latest n from '## Attempts' ATTEMPT ship-red, else 0
# Reads only; missing file → empty/0. Exit: 0 ok · 3 unknown subcommand.
set -eu
cmd="${1:-}"
case "$cmd" in
  field)
    name="${2:-}"; file="${3:-.workflow/state.md}"
    [ -f "$file" ] || { printf ''; exit 0; }
    # match '| <name> | <value> |' inside the doc; print trimmed value
    awk -v k="$name" '
      $0 ~ ("^\\| *" k " *\\|") {
        line=$0; sub(/^\| *[^|]* *\| */, "", line); sub(/ *\|.*$/, "", line);
        print line; exit
      }' "$file"
    ;;
  round-count)
    loop="${2:-}"; file="${3:-.workflow/state.md}"
    [ -f "$file" ] || { echo 0; exit 0; }
    grep -c "loop=$loop .*kind=round" "$file" 2>/dev/null || echo 0
    ;;
  ship-red-count)
    file="${2:-.workflow/state.md}"
    [ -f "$file" ] || { echo 0; exit 0; }
    n=$(grep 'ATTEMPT ship-red' "$file" 2>/dev/null | sed -n 's/.*n=\([0-9][0-9]*\).*/\1/p' | tail -1)
    [ -n "$n" ] && echo "$n" || echo 0
    ;;
  *) echo "goal-state: unknown subcommand '$cmd'" >&2; exit 3 ;;
esac
```

- [ ] **Step 4: Run to verify they pass**

Run: `node --test tools/test/goal-state.test.mjs`
Expected: PASS (all three tests).

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-state.sh tools/test/goal-state.test.mjs
git commit -m "feat(goal): goal-state.sh field/round-count/ship-red readers"
```

---

### Task 5: `goal-state.sh` — `ship-red-bump` (durable increment)

**Files:**
- Modify: `src/shared/scripts/goal-state.sh`
- Test: `tools/test/goal-state.test.mjs`

**Interfaces:**
- Produces: `goal-state.sh ship-red-bump [state.md]` → appends `- ATTEMPT ship-red — n=<k+1> —
  ts=<ISO>` under a `## Attempts` header (creating the header if absent), and prints the new `n`.
  This is the durable counter that makes "second ship-red → HALT" survive a compaction (§6.2/P1-4).

- [ ] **Step 1: Write the failing test**

Append to `tools/test/goal-state.test.mjs`:

```js
test('ship-red-bump appends an incremented durable counter', () => {
  const dir = stateFile('## /goal loop\n| phase | ship |\n');
  assert.equal(run(['ship-red-bump', 'state.md'], dir), '1'); // first red
  assert.equal(run(['ship-red-bump', 'state.md'], dir), '2'); // second → caller HALTs
  assert.equal(run(['ship-red-count', 'state.md'], dir), '2'); // persisted across calls
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `node --test tools/test/goal-state.test.mjs`
Expected: FAIL — `ship-red-bump` is an unknown subcommand (exit 3).

- [ ] **Step 3: Add the `ship-red-bump` case**

Insert before the `*)` default case in `goal-state.sh`:

```sh
  ship-red-bump)
    file="${2:-.workflow/state.md}"
    cur=$(sh "$0" ship-red-count "$file")   # reuse the reader (DRY)
    next=$((cur + 1))
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    [ -f "$file" ] || : > "$file"
    grep -q '^## Attempts' "$file" 2>/dev/null || printf '\n## Attempts\n' >> "$file"
    printf -- '- ATTEMPT ship-red — n=%s — ts=%s\n' "$next" "$ts" >> "$file"
    echo "$next"
    ;;
```

- [ ] **Step 4: Run to verify it passes**

Run: `node --test tools/test/goal-state.test.mjs`
Expected: PASS (all four tests).

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-state.sh tools/test/goal-state.test.mjs
git commit -m "feat(goal): goal-state.sh ship-red-bump durable counter"
```

---

### Task 6: `goal-state.ps1` — PowerShell parity

**Files:**
- Create: `src/shared/scripts/goal-state.ps1`
- Test: `tools/test/goal-state.ps1.test.mjs`

**Interfaces:**
- Produces: `pwsh goal-state.ps1 <subcommand> …` with identical output to `goal-state.sh` for
  `field`, `round-count`, `ship-red-count`, `ship-red-bump`.

- [ ] **Step 1: Write the failing parity test**

Create `tools/test/goal-state.ps1.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const SH  = new URL('../../src/shared/scripts/goal-state.sh',  import.meta.url).pathname;
const PS1 = new URL('../../src/shared/scripts/goal-state.ps1', import.meta.url).pathname;
const hasPwsh = spawnSync('pwsh', ['-v'], { stdio: 'ignore' }).status === 0;
const STATE = `## /goal loop
| phase | code-review |

## Review log
- loop=code — round=1 — kind=round — reviewer=codex — result=P1=1 — digest=aa — ts=t1
- loop=code — round=2 — kind=cert — reviewer=self — result=clean — digest=bb — ts=t2
`;

test('goal-state.ps1 matches .sh for reads', { skip: !hasPwsh }, () => {
  const dir = mkdtempSync(join(tmpdir(), 'goalstp-'));
  writeFileSync(join(dir, 'state.md'), STATE);
  const sh  = (a) => execFileSync('sh',   [SH,  ...a], { cwd: dir }).toString().trim();
  const ps1 = (a) => execFileSync('pwsh', ['-NoProfile', '-File', PS1, ...a], { cwd: dir }).toString().trim();
  for (const a of [['field', 'phase', 'state.md'], ['round-count', 'code', 'state.md'], ['ship-red-count', 'state.md']]) {
    assert.equal(ps1(a), sh(a), `mismatch for ${a.join(' ')}`);
  }
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `node --test tools/test/goal-state.ps1.test.mjs`
Expected: FAIL (ps1 missing) or SKIP without `pwsh`.

- [ ] **Step 3: Write the PowerShell twin**

Create `src/shared/scripts/goal-state.ps1`:

```powershell
#!/usr/bin/env pwsh
# goal-state.ps1 — PowerShell twin of goal-state.sh (design §4/§6.2/§10).
param([Parameter(Mandatory)][string]$Cmd, [string]$A2 = '', [string]$A3 = '')
$ErrorActionPreference = 'Stop'
function DefaultFile($f) { if ($f) { $f } else { '.workflow/state.md' } }

switch ($Cmd) {
  'field' {
    $name = $A2; $file = DefaultFile $A3
    if (-not (Test-Path $file)) { return }
    foreach ($line in Get-Content $file) {
      if ($line -match "^\|\s*$([regex]::Escape($name))\s*\|\s*(.*?)\s*\|") { $matches[1]; break }
    }
  }
  'round-count' {
    $loop = $A2; $file = DefaultFile $A3
    if (-not (Test-Path $file)) { '0'; break }
    (Get-Content $file | Where-Object { $_ -match "loop=$loop .*kind=round" }).Count
  }
  'ship-red-count' {
    $file = DefaultFile $A2
    if (-not (Test-Path $file)) { '0'; break }
    $ns = Get-Content $file | ForEach-Object { if ($_ -match 'ATTEMPT ship-red.*n=(\d+)') { [int]$matches[1] } }
    if ($ns) { $ns[-1] } else { '0' }
  }
  'ship-red-bump' {
    $file = DefaultFile $A2
    $cur = [int](& pwsh -NoProfile -File $PSCommandPath 'ship-red-count' $file)
    $next = $cur + 1
    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    if (-not (Test-Path $file)) { New-Item -ItemType File -Path $file | Out-Null }
    if (-not (Select-String -Path $file -Pattern '^## Attempts' -Quiet)) { Add-Content $file "`n## Attempts" }
    Add-Content $file "- ATTEMPT ship-red — n=$next — ts=$ts"
    $next
  }
  default { Write-Error "goal-state: unknown subcommand '$Cmd'"; exit 3 }
}
```

- [ ] **Step 4: Run to verify parity passes**

Run: `node --test tools/test/goal-state.ps1.test.mjs`
Expected: PASS on a `pwsh` machine (and CI windows job). Reconcile until identical if not.

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-state.ps1 tools/test/goal-state.ps1.test.mjs
git commit -m "feat(goal): goal-state.ps1 PowerShell parity"
```

---

### Task 7: Wire the new tests into CI (both OS jobs)

**Files:**
- Modify: `.github/workflows/ci.yml` (only if it enumerates test files rather than globbing —
  otherwise no change; verify)

**Interfaces:** none (CI wiring).

- [ ] **Step 1: Check how CI selects tests**

Run: `grep -n "node --test" .github/workflows/ci.yml`
Expected: either a glob (`tools/test/*.test.mjs` — nothing to do) or an explicit list.

- [ ] **Step 2: If explicit, add the four new files; else confirm the glob covers them**

If the list is explicit, add `tools/test/goal-digest.test.mjs`, `tools/test/goal-digest.ps1.test.mjs`,
`tools/test/goal-state.test.mjs`, `tools/test/goal-state.ps1.test.mjs` to BOTH the ubuntu and
windows jobs. The `.ps1` parity tests self-skip where `pwsh` is absent (ubuntu) and run on the
windows job. (No new deps → no `npm ci` change needed; these tests are zero-dep.)

- [ ] **Step 3: Run the whole suite locally**

Run: `node --test tools/test/`
Expected: PASS; the two `.ps1.test.mjs` SKIP locally if `pwsh` is absent.

- [ ] **Step 4: Run the linter (no new skill, but keep the gate green)**

Run: `npm run check`
Expected: lint + evals + tests green.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci(goal): run goal-digest/goal-state helper tests on both OS jobs"
```

---

## Self-Review

**Spec coverage (Plan A scope only — the §6.1 digest + §6.2/§10 counters):**
- §6.1 digest membership (tracked diff vs base + untracked, exclusion set both clauses) → Tasks 1–2. ✓
- §6.1 framing (path+mode+length+content; rename/empty move it) → Task 2 tests. ✓
- §6.1 determinism (LC_ALL=C, --no-renames, sorted) → Task 1 impl + determinism test. ✓
- sh/ps1 parity → Tasks 3, 6 parity tests. ✓
- §6.2 breaker count (kind=round per loop) → Task 4 `round-count`. ✓
- §6.2/P1-4 durable ship-red counter → Tasks 4–5 `ship-red-count`/`ship-red-bump`. ✓
- §10 review-log + attempt schemas parsed exactly as written → Tasks 4–5 test fixtures. ✓
- NOT in Plan A (later plans): the `field` write path, gate1/gate2/SIMPLIFY/blocker writers, the
  byte-level `git add -N` normalization refinement (Task 2 uses direct framing, which the tests
  prove sufficient for rename/empty; if a future case needs `add -N`, it's a Plan-A follow-up task),
  the skill, the generator, the evals. Those are Plan B/C.

**Placeholder scan:** every code step has complete, runnable content; no TBD/TODO. ✓

**Type/name consistency:** subcommand names (`field`, `round-count`, `ship-red-count`,
`ship-red-bump`) and the digest signature (`<base_sha> [repo_dir]`) are identical across the `.sh`,
`.ps1`, and every test. Exclusion set is identical (verbatim) in `goal-digest.sh`, `goal-digest.ps1`,
and the Global Constraints. ✓

**Known risk flagged for the reviewer:** the digest byte-stream must be identical between `.sh`
(pipes text to `sha256`) and `.ps1` (builds a `MemoryStream`). Task 3's parity test is the arbiter;
if it fails, the fix is to align framing/newlines, not to weaken the test. This is the sh↔ps1 drift
class that bit this project before — treat a parity failure as P1.
