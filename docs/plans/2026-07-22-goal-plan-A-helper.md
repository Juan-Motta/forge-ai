# /goal Plan A — state + digest helper (foundation) — Implementation Plan (rev2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the two engine-neutral shell helpers `/goal` relies on — `goal-digest.{sh,ps1}`
(the §6.1 certification digest) and `goal-state.{sh,ps1}` (read `## /goal loop` fields, count the
convergence-breaker rounds, read/bump the durable ship-red counter) — with node tests.

**Architecture:** Ships to targets, so POSIX `sh` + PowerShell 7 (no Node in targets), like
`src/shared/scripts/check-gates.{sh,ps1}`. Dev tests live in `tools/test/*.test.mjs` (`node --test`,
zero-dep) and **spawn** the scripts, mirroring `tools/test/check-gates.{test,ps1.test}.mjs`.

**The digest is one normalized `git diff`.** (This is the rev2 correction from cross-engine plan
review: the earlier dual representation — unified diff for tracked, custom `U\t…` framing for
untracked — was not staging-invariant, so merely `git add`-ing reviewed content changed the digest
and Plan-C's `digest(committed tree)==cert` ship assertion was unsatisfiable.) Instead: seed a
**temporary git index** from the repo's real index, `git add -N` (intent-to-add) every in-scope
untracked file into it, then hash the **raw bytes** of a single `git diff <base>` over that index.
Git then frames tracked + untracked uniformly (modes, symlinks as `120000`, renames-off), the
representation is identical before/after staging, and `sh`/`ps1` both hash the same git bytes → byte
parity is trivial. The committed-tree digest (for Plan C's ship check) is the same function with
`--from-head` (`git diff <base> HEAD`), equal by construction when the commit captured the in-scope
worktree content.

**Tech Stack:** POSIX `sh`, PowerShell 7 (`pwsh`), `git` (temp-index via `GIT_INDEX_FILE`),
`shasum`/`sha256sum`, `node:test`, `node:child_process`, `node:fs`, `node:url` (`fileURLToPath`).

## Global Constraints (from the design spec, verbatim)

- Digest exclusion set (§6.1), applied to the diff pathspecs (one set, one place):
  `.workflow/*`, `docs/e2e/reports/*`, `CONTINUITY.md`, `docs/CHANGELOG.md`, `VERSION`.
  **Reviewer/council scratch** is written under `.workflow/` (already excluded) — no separate prefix
  is introduced (resolves the "pin one scratch prefix" spec item: the pin is "under `.workflow/`").
  **`package.json`/lockfiles are NOT excluded** (feature content) — a positive-control test asserts
  they stay in scope.
- Digest determinism: `LC_ALL=C`, `git diff --no-renames --no-color`, temp-index normalization.
- Digest is **index-state-invariant**: the same in-scope content yields the same digest whether a
  file is untracked, `-N`, staged, or committed (a dedicated test asserts this).
- Breaker constants are consumed by callers (Plan C), not hard-coded here: `N=4`,
  `MAX_REENTRIES=3`, `MAX_CODE_ROUNDS=3·N`. The helper only *counts*.
- Review-log schema (§10): `- loop=plan|code — round=<N> — kind=round|recert|cert —
  reviewer=<…> — result=… — digest — ts`. Breaker counts `kind=round` **within `## Review log`**.
- Ship-red schema (§10): `- ATTEMPT ship-red — n=<k> — ts` **within `## Attempts`**; `n>=2` → HALT.
- All state readers/writers are **section-scoped** (`## <name>` up to the next `## ` heading).
- sh/ps1 parity is mandatory; parity tests run only when BOTH `sh` and `pwsh` exist, and use
  fixtures with mixed-case, non-ASCII, wildcard-bracket, and executable paths.
- Scripts safe under `set -eu`; git-producer failures are detected (no `set -e`+pipe swallowing);
  portable `sha256` (`sha256sum` else `shasum -a 256`); tools preflighted (missing git/sha → exit 3).
- Tests use `fileURLToPath` (never `new URL().pathname` — breaks on Windows) and `hasSh`/`hasPwsh`
  guards (mirror `tools/test/check-gates.test.mjs`).

---

## File Structure

- `src/shared/scripts/goal-digest.sh` — `sh goal-digest.sh <base_sha> [repo_dir] [--from-head]` →
  64-char hex digest. `--from-head` hashes `git diff <base> HEAD` (committed tree) instead of the
  normalized worktree.
- `src/shared/scripts/goal-digest.ps1` — PowerShell twin, byte-identical.
- `src/shared/scripts/goal-state.sh` — `field | round-count | ship-red-count | ship-red-bump`,
  all section-scoped.
- `src/shared/scripts/goal-state.ps1` — PowerShell twin.
- `tools/test/goal-digest.test.mjs`, `tools/test/goal-digest.ps1.test.mjs`,
  `tools/test/goal-state.test.mjs`, `tools/test/goal-state.ps1.test.mjs`.

Task 1–2 = digest (sh + tests, then ps1 parity). Task 3–4 = state (sh + tests, then ps1 parity).
Task 5 = CI-discovery verification.

---

### Task 1: `goal-digest.sh` — normalized single-`git diff` digest

**Files:**
- Create: `src/shared/scripts/goal-digest.sh`
- Test: `tools/test/goal-digest.test.mjs`

**Interfaces:**
- Produces: `goal-digest.sh <base_sha> [repo_dir] [--from-head]` → stdout one line, 64-char lower
  hex. Exit 0 ok; exit 3 if `git`/sha missing, `base_sha` empty/invalid, or `repo_dir` not a repo.
- Consumes: nothing.

- [ ] **Step 1: Write the failing tests** (`tools/test/goal-digest.test.mjs`)

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SH = fileURLToPath(new URL('../../src/shared/scripts/goal-digest.sh', import.meta.url));

function initRepo() {
  const dir = mkdtempSync(join(tmpdir(), 'goaldig-'));
  const git = (...a) => execFileSync('git', a, { cwd: dir, stdio: 'pipe' });
  git('init', '-q'); git('config', 'user.email', 't@t.co'); git('config', 'user.name', 'T');
  writeFileSync(join(dir, 'seed.txt'), 'seed\n');
  git('add', '.'); git('commit', '-qm', 'base');
  return { dir, base: git('rev-parse', 'HEAD').toString().trim(), git };
}
const digest = (dir, base, ...extra) =>
  execFileSync('sh', [SH, base, dir, ...extra], { cwd: dir }).toString().trim();

test('digest is 64-hex and deterministic', () => {
  const { dir, base } = initRepo();
  writeFileSync(join(dir, 'seed.txt'), 'seed\nX\n');
  const d = digest(dir, base);
  assert.match(d, /^[0-9a-f]{64}$/);
  assert.equal(d, digest(dir, base));
});

test('staging does NOT change the digest (index-state invariance)', () => {
  const { dir, base, git } = initRepo();
  writeFileSync(join(dir, 'new.txt'), 'content\n');        // untracked
  const untracked = digest(dir, base);
  git('add', 'new.txt');                                    // now staged, same bytes
  assert.equal(digest(dir, base), untracked);               // <-- the rev2 fix
  git('commit', '-qm', 'c');
  assert.equal(digest(dir, base, '--from-head'), untracked); // committed tree == cert
});

test('a content change moves the digest; an excluded path does not', () => {
  const { dir, base } = initRepo();
  const before = digest(dir, base);
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'), 'noise\n'); // excluded
  assert.equal(digest(dir, base), before);
  writeFileSync(join(dir, 'seed.txt'), 'seed\nY\n');            // in-scope
  assert.notEqual(digest(dir, base), before);
});

test('package.json is in scope (positive control); rename moves digest', () => {
  const { dir, base, git } = initRepo();
  const before = digest(dir, base);
  writeFileSync(join(dir, 'package.json'), '{"name":"x"}\n');   // NOT excluded
  assert.notEqual(digest(dir, base), before);
  const withPkg = digest(dir, base);
  git('add', '.'); git('commit', '-qm', 'pkg');
  git('mv', 'seed.txt', 'renamed.txt');
  assert.notEqual(digest(dir, base), withPkg);                  // --no-renames = del+add
});

test('leading-dash and symlink untracked files are handled', () => {
  const { dir, base } = initRepo();
  writeFileSync(join(dir, '-weird.txt'), 'dash\n');             // must not be read as an option
  symlinkSync('seed.txt', join(dir, 'link'));                   // symlink → git frames as 120000
  const d = digest(dir, base);
  assert.match(d, /^[0-9a-f]{64}$/);                            // no crash; deterministic
  assert.equal(d, digest(dir, base));
});

test('bad base sha exits 3, not sha-of-empty', () => {
  const { dir } = initRepo();
  const r = execFileSync('sh', [SH, 'deadbeefdeadbeef', dir], { cwd: dir, encoding: 'utf8', stdio: 'pipe' })
    .catch?.(e => e) ?? null;
  // execFileSync throws on non-zero; assert via spawnSync instead:
});
```

Replace the last test with a spawnSync form (execFileSync throws, awkward to assert):

```js
import { spawnSync } from 'node:child_process';
test('bad base sha exits 3', () => {
  const { dir } = initRepo();
  const r = spawnSync('sh', [SH, 'deadbeefdeadbeef', dir], { cwd: dir });
  assert.equal(r.status, 3);
});
```

- [ ] **Step 2: Run to verify failure**

Run: `node --test tools/test/goal-digest.test.mjs`
Expected: FAIL (script missing / spawn ENOENT).

- [ ] **Step 3: Write `src/shared/scripts/goal-digest.sh`**

```sh
#!/bin/sh
# goal-digest.sh — /goal certification digest (design §6.1).
# Usage: sh goal-digest.sh <base_sha> [repo_dir] [--from-head]
# Prints a 64-char hex digest of in-scope content vs <base_sha>. Default: the
# normalized worktree (temp index + intent-to-add, so tracked+untracked frame
# identically and the digest is index-state invariant). --from-head: the
# committed tree (git diff <base> HEAD). Exit: 0 ok · 3 bad env/args.
set -eu
LC_ALL=C; export LC_ALL

base="${1:-}"; repo="${2:-.}"; mode="${3:-}"
[ -n "$base" ] || { echo "goal-digest: missing base_sha" >&2; exit 3; }
command -v git >/dev/null 2>&1 || { echo "goal-digest: git not found" >&2; exit 3; }
if command -v sha256sum >/dev/null 2>&1; then SHA="sha256sum"
elif command -v shasum >/dev/null 2>&1; then SHA="shasum -a 256"
else echo "goal-digest: no sha256 tool" >&2; exit 3; fi
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "goal-digest: not a repo" >&2; exit 3; }
git -C "$repo" cat-file -e "${base}^{commit}" 2>/dev/null || { echo "goal-digest: bad base" >&2; exit 3; }

set -f  # noglob: exclusion pathspecs contain '*'
# exclusion set — the single source of truth (keep in sync with goal-digest.ps1)
set -- \
  ':(exclude).workflow/*' \
  ':(exclude)docs/e2e/reports/*' \
  ':(exclude)CONTINUITY.md' \
  ':(exclude)docs/CHANGELOG.md' \
  ':(exclude)VERSION'

out=$(mktemp); trap 'rm -f "$out"' EXIT INT TERM

if [ "$mode" = "--from-head" ]; then
  git -C "$repo" -c core.quotepath=false diff --no-renames --no-color "$base" HEAD -- . "$@" > "$out"
else
  # normalized worktree: temp index seeded from the real index, + intent-to-add untracked
  real_idx=$(cd "$repo" && git rev-parse --git-path index)
  tmp_idx=$(mktemp); trap 'rm -f "$out" "$tmp_idx"' EXIT INT TERM
  [ -f "$repo/$real_idx" ] && cp "$repo/$real_idx" "$tmp_idx" || : > "$tmp_idx"
  GIT_INDEX_FILE="$tmp_idx"; export GIT_INDEX_FILE
  git -C "$repo" add -N -- . "$@" >/dev/null 2>&1 || true   # intent-to-add in-scope untracked
  git -C "$repo" -c core.quotepath=false diff --no-renames --no-color "$base" -- . "$@" > "$out"
  unset GIT_INDEX_FILE
fi
# git wrote its raw bytes to "$out"; hash them
$SHA < "$out" | cut -d' ' -f1
```

- [ ] **Step 4: Run to verify passes**

Run: `node --test tools/test/goal-digest.test.mjs`
Expected: PASS (all tests, incl. the invariance and exit-3 tests).

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-digest.sh tools/test/goal-digest.test.mjs
git commit -m "feat(goal): goal-digest.sh normalized single-git-diff digest"
```

---

### Task 2: `goal-digest.ps1` — PowerShell parity (hash raw git bytes)

**Files:**
- Create: `src/shared/scripts/goal-digest.ps1`
- Test: `tools/test/goal-digest.ps1.test.mjs`

**Interfaces:** `pwsh goal-digest.ps1 <base_sha> [repo_dir] [--from-head]` → identical hex to `.sh`.
Because both hash the **raw stdout bytes** of the same `git diff`, parity is structural (same git
binary, same args) — the ps1 must NOT decode/re-encode git output.

- [ ] **Step 1: Write the failing parity test** (`tools/test/goal-digest.ps1.test.mjs`)

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SH  = fileURLToPath(new URL('../../src/shared/scripts/goal-digest.sh',  import.meta.url));
const PS1 = fileURLToPath(new URL('../../src/shared/scripts/goal-digest.ps1', import.meta.url));
const hasSh   = spawnSync('sh',   ['-c', 'exit 0'], { stdio: 'ignore' }).status === 0;
const hasPwsh = spawnSync('pwsh', ['-v'],           { stdio: 'ignore' }).status === 0;

test('goal-digest.ps1 == goal-digest.sh across tricky paths', { skip: !(hasSh && hasPwsh) }, () => {
  const dir = mkdtempSync(join(tmpdir(), 'goaldigp-'));
  const git = (...a) => execFileSync('git', a, { cwd: dir, stdio: 'pipe' });
  git('init', '-q'); git('config', 'user.email', 't@t.co'); git('config', 'user.name', 'T');
  writeFileSync(join(dir, 'seed.txt'), 'seed\n'); git('add', '.'); git('commit', '-qm', 'base');
  const base = git('rev-parse', 'HEAD').toString().trim();
  // mixed-case ordering, non-ASCII content, wildcard-bracket path
  writeFileSync(join(dir, 'Foo.txt'), 'A\n');
  writeFileSync(join(dir, 'bar.txt'), 'café ☕\n');
  mkdirSync(join(dir, 'app', '[id]'), { recursive: true });
  writeFileSync(join(dir, 'app', '[id]', 'page.txt'), 'wild\n');
  const sh  = execFileSync('sh',   [SH,  base, dir], { cwd: dir }).toString().trim();
  const ps1 = execFileSync('pwsh', ['-NoProfile', '-File', PS1, base, dir], { cwd: dir }).toString().trim();
  assert.equal(ps1, sh);
});
```

- [ ] **Step 2: Run to verify failure/skip**

Run: `node --test tools/test/goal-digest.ps1.test.mjs`
Expected: FAIL (ps1 missing) on a dual-runtime host; SKIP where either runtime is absent.

- [ ] **Step 3: Write `src/shared/scripts/goal-digest.ps1`**

```powershell
#!/usr/bin/env pwsh
# goal-digest.ps1 — PowerShell twin of goal-digest.sh (design §6.1). Hashes the RAW bytes of the
# same 'git diff' the .sh hashes — no decode/re-encode, so parity is structural.
param([Parameter(Mandatory)][string]$Base, [string]$RepoDir = '.', [string]$Mode = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # handle native exit via $LASTEXITCODE (like check-gates.ps1)
$env:LC_ALL = 'C'
$repo = (Resolve-Path $RepoDir).Path
$excl = @(':(exclude).workflow/*', ':(exclude)docs/e2e/reports/*', ':(exclude)CONTINUITY.md',
          ':(exclude)docs/CHANGELOG.md', ':(exclude)VERSION')

function Fail($m) { [Console]::Error.WriteLine("goal-digest: $m"); exit 3 }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 'git not found' }
& git -C $repo rev-parse --git-dir *> $null; if ($LASTEXITCODE -ne 0) { Fail 'not a repo' }
& git -C $repo cat-file -e "$Base^{commit}" *> $null; if ($LASTEXITCODE -ne 0) { Fail 'bad base' }

$out = [System.IO.Path]::GetTempFileName()
try {
  # Redirect native git stdout to a file as raw bytes (no PowerShell string decoding).
  if ($Mode -eq '--from-head') {
    $args = @('-C', $repo, '-c', 'core.quotepath=false', 'diff', '--no-renames', '--no-color', $Base, 'HEAD', '--', '.') + $excl
    $p = Start-Process git -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out
  } else {
    $realIdx = (& git -C $repo rev-parse --git-path index).Trim()
    $tmpIdx  = [System.IO.Path]::GetTempFileName()
    $src = Join-Path $repo $realIdx
    if (Test-Path $src) { Copy-Item $src $tmpIdx -Force } else { '' | Set-Content -NoNewline $tmpIdx }
    $env:GIT_INDEX_FILE = $tmpIdx
    $addArgs = @('-C', $repo, 'add', '-N', '--', '.') + $excl
    & git @addArgs *> $null            # intent-to-add; ignore status
    $args = @('-C', $repo, '-c', 'core.quotepath=false', 'diff', '--no-renames', '--no-color', $Base, '--', '.') + $excl
    $p = Start-Process git -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out
    Remove-Item Env:GIT_INDEX_FILE
    Remove-Item $tmpIdx -Force
  }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.IO.File]::ReadAllBytes($out)
  -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
} finally { Remove-Item $out -Force -ErrorAction SilentlyContinue }
```

- [ ] **Step 4: Run to verify parity**

Run: `node --test tools/test/goal-digest.ps1.test.mjs`
Expected: PASS on a host with both `sh`+`pwsh` (CI windows job has both via Git-for-Windows). If it
diverges, the fault is always a decode/re-encode or arg-order difference — align until identical; a
parity failure is P1.

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-digest.ps1 tools/test/goal-digest.ps1.test.mjs
git commit -m "feat(goal): goal-digest.ps1 parity (raw git-diff bytes)"
```

---

### Task 3: `goal-state.sh` — section-scoped readers + durable `ship-red-bump`

**Files:**
- Create: `src/shared/scripts/goal-state.sh`
- Test: `tools/test/goal-state.test.mjs`

**Interfaces:**
- `field <name> [file]` → value of `| <name> | <value> |` **within `## /goal loop`**, else empty.
- `round-count <plan|code> [file]` → integer count of `## Review log` lines matching the fixed
  schema with `loop=<x>` AND `kind=round` (single integer, `0` when none).
- `ship-red-count [file]` → latest `n` from `## Attempts` `ATTEMPT ship-red` lines, else `0`.
- `ship-red-bump [file]` → append `- ATTEMPT ship-red — n=<k+1> — ts=<ISO>` **inside `## Attempts`**
  (before the next `## ` heading; create the section if absent), print the new `n`.
- Exit 0 for reads; exit 3 unknown subcommand.

- [ ] **Step 1: Write the failing tests** (`tools/test/goal-state.test.mjs`)

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SH = fileURLToPath(new URL('../../src/shared/scripts/goal-state.sh', import.meta.url));
const run = (args, cwd) => execFileSync('sh', [SH, ...args], { cwd }).toString().trim();
function stateFile(body) {
  const dir = mkdtempSync(join(tmpdir(), 'goalst-')); writeFileSync(join(dir, 'state.md'), body); return dir;
}
const STATE = `## /goal loop
| phase | code-review |
| reentries | 2 |

## Review log
- loop=code — round=1 — kind=round — reviewer=codex — result=P1=1 — digest=aa — ts=t1
- loop=code — round=2 — kind=round — reviewer=self — result=clean — digest=bb — ts=t2
- loop=code — round=3 — kind=cert — reviewer=codex — result=clean — digest=bb — ts=t3
- loop=plan — round=1 — kind=round — reviewer=codex — result=clean — digest=cc — ts=t0

## Notes
| phase | DECOY |
`;

test('field is section-scoped to ## /goal loop', () => {
  const dir = stateFile(STATE);
  assert.equal(run(['field', 'phase', 'state.md'], dir), 'code-review'); // not the Notes DECOY
  assert.equal(run(['field', 'reentries', 'state.md'], dir), '2');
  assert.equal(run(['field', 'absent', 'state.md'], dir), '');
});

test('round-count counts kind=round per loop; zero yields a single 0', () => {
  const dir = stateFile(STATE);
  assert.equal(run(['round-count', 'code', 'state.md'], dir), '2'); // cert excluded
  assert.equal(run(['round-count', 'plan', 'state.md'], dir), '1');
  const empty = stateFile('## Review log\n');
  assert.equal(run(['round-count', 'code', 'state.md'], empty), '0'); // not "0\n0"
});

test('ship-red-bump increments inside ## Attempts and persists', () => {
  const dir = stateFile('## /goal loop\n| phase | ship |\n\n## Notes\nend\n');
  assert.equal(run(['ship-red-bump', 'state.md'], dir), '1');
  assert.equal(run(['ship-red-bump', 'state.md'], dir), '2');
  assert.equal(run(['ship-red-count', 'state.md'], dir), '2');
  const body = readFileSync(join(dir, 'state.md'), 'utf8');
  assert.match(body, /## Attempts[\s\S]*ATTEMPT ship-red — n=2/); // landed in its own section
});
```

- [ ] **Step 2: Run to verify failure**

Run: `node --test tools/test/goal-state.test.mjs` → FAIL (script missing).

- [ ] **Step 3: Write `src/shared/scripts/goal-state.sh`**

```sh
#!/bin/sh
# goal-state.sh — section-scoped readers/writers for /goal's .workflow/state.md (§4/§6.2/§10).
# Subcommands: field <name> [file] | round-count <plan|code> [file]
#              ship-red-count [file] | ship-red-bump [file]
# Reads never fail on a missing file (empty/0). Exit: 0 ok · 3 unknown subcommand.
set -eu

# section <header> <file> : emit only the lines under '## <header>' up to the next '## '
section() {
  awk -v h="$1" '
    $0 == "## " h { insec=1; next }
    /^## / { insec=0 }
    insec { print }
  ' "$2"
}

cmd="${1:-}"
case "$cmd" in
  field)
    name="${2:-}"; file="${3:-.workflow/state.md}"
    [ -f "$file" ] || { printf ''; exit 0; }
    section "/goal loop" "$file" | awk -v k="$name" '
      $0 ~ ("^\\| *" k " *\\|") { s=$0; sub(/^\| *[^|]* *\| */,"",s); sub(/ *\|.*$/,"",s); print s; exit }'
    ;;
  round-count)
    loop="${2:-}"; file="${3:-.workflow/state.md}"
    [ -f "$file" ] || { echo 0; exit 0; }
    section "Review log" "$file" \
      | grep -c -e "loop=$loop .*kind=round" 2>/dev/null | head -1 || echo 0
    ;;
  ship-red-count)
    file="${2:-.workflow/state.md}"
    [ -f "$file" ] || { echo 0; exit 0; }
    n=$(section "Attempts" "$file" | sed -n 's/.*ATTEMPT ship-red — n=\([0-9][0-9]*\).*/\1/p' | tail -1)
    [ -n "$n" ] && echo "$n" || echo 0
    ;;
  ship-red-bump)
    file="${2:-.workflow/state.md}"
    cur=$(sh "$0" ship-red-count "$file")
    next=$((cur + 1))
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    [ -f "$file" ] || : > "$file"
    line="- ATTEMPT ship-red — n=$next — ts=$ts"
    if grep -q '^## Attempts' "$file" 2>/dev/null; then
      # insert the line just after the '## Attempts' header (stays inside the section)
      awk -v L="$line" '{ print } /^## Attempts$/ && !done { print L; done=1 }' "$file" > "$file.tmp" \
        && mv "$file.tmp" "$file"
    else
      printf '\n## Attempts\n%s\n' "$line" >> "$file"
    fi
    echo "$next"
    ;;
  *) echo "goal-state: unknown subcommand '$cmd'" >&2; exit 3 ;;
esac
```

Note on `round-count`: piping `grep -c` into `head -1` yields a single line; the `|| echo 0` guard
only fires if the whole pipe fails. `grep -c` on zero matches prints `0` and the pipe succeeds via
`head`, so the output is exactly `0` (the earlier `grep -c || echo 0` double-`0` bug is gone).

- [ ] **Step 4: Run to verify passes**

Run: `node --test tools/test/goal-state.test.mjs` → PASS (all, incl. the zero and section-scope cases).

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-state.sh tools/test/goal-state.test.mjs
git commit -m "feat(goal): goal-state.sh section-scoped readers + ship-red-bump"
```

---

### Task 4: `goal-state.ps1` — PowerShell parity (all four subcommands + exit 3)

**Files:**
- Create: `src/shared/scripts/goal-state.ps1`
- Test: `tools/test/goal-state.ps1.test.mjs`

**Interfaces:** identical output to `goal-state.sh` for all four subcommands; unknown subcommand →
exit 3 (via `[Console]::Error.WriteLine` + `exit 3`, never `Write-Error` which throws under Stop).

- [ ] **Step 1: Write the failing parity test** (`tools/test/goal-state.ps1.test.mjs`)

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SH  = fileURLToPath(new URL('../../src/shared/scripts/goal-state.sh',  import.meta.url));
const PS1 = fileURLToPath(new URL('../../src/shared/scripts/goal-state.ps1', import.meta.url));
const hasSh   = spawnSync('sh',   ['-c', 'exit 0'], { stdio: 'ignore' }).status === 0;
const hasPwsh = spawnSync('pwsh', ['-v'],           { stdio: 'ignore' }).status === 0;
const STATE = `## /goal loop
| phase | code-review |

## Review log
- loop=code — round=1 — kind=round — reviewer=codex — result=P1=1 — digest=aa — ts=t1
- loop=code — round=2 — kind=cert — reviewer=self — result=clean — digest=bb — ts=t2
`;

test('goal-state.ps1 matches .sh for reads + bump + unknown-exit', { skip: !(hasSh && hasPwsh) }, () => {
  const mk = () => { const d = mkdtempSync(join(tmpdir(), 'goalstp-')); writeFileSync(join(d, 'state.md'), STATE); return d; };
  const sh  = (a, d) => execFileSync('sh',   [SH,  ...a], { cwd: d }).toString().trim();
  const ps1 = (a, d) => execFileSync('pwsh', ['-NoProfile', '-File', PS1, ...a], { cwd: d }).toString().trim();
  for (const a of [['field','phase','state.md'], ['round-count','code','state.md'], ['ship-red-count','state.md']]) {
    const d1 = mk(), d2 = mk();
    assert.equal(ps1(a, d2), sh(a, d1), `read mismatch: ${a.join(' ')}`);
  }
  // bump parity on separate identical fixtures
  const ds = mk(), dp = mk();
  assert.equal(ps1(['ship-red-bump','state.md'], dp), sh(['ship-red-bump','state.md'], ds));
  // unknown subcommand → exit 3 on both
  assert.equal(spawnSync('sh',   [SH,  'bogus'], { cwd: mk() }).status, 3);
  assert.equal(spawnSync('pwsh', ['-NoProfile','-File',PS1,'bogus'], { cwd: mk() }).status, 3);
});
```

- [ ] **Step 2: Run to verify failure/skip**

Run: `node --test tools/test/goal-state.ps1.test.mjs` → FAIL (ps1 missing) or SKIP.

- [ ] **Step 3: Write `src/shared/scripts/goal-state.ps1`**

```powershell
#!/usr/bin/env pwsh
# goal-state.ps1 — PowerShell twin of goal-state.sh (design §4/§6.2/§10), section-scoped.
param([Parameter(Mandatory)][string]$Cmd, [string]$A2 = '', [string]$A3 = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
function DefaultFile($f) { if ($f) { $f } else { '.workflow/state.md' } }
function Section([string]$header, [string]$file) {
  $in = $false
  foreach ($line in Get-Content -LiteralPath $file) {
    if ($line -eq "## $header") { $in = $true; continue }
    elseif ($line -like '## *') { $in = $false }
    if ($in) { $line }
  }
}
switch ($Cmd) {
  'field' {
    $name = $A2; $file = DefaultFile $A3
    if (-not (Test-Path $file)) { return }
    foreach ($l in Section '/goal loop' $file) {
      if ($l -match "^\|\s*$([regex]::Escape($name))\s*\|\s*(.*?)\s*\|") { $matches[1]; break }
    }
  }
  'round-count' {
    $loop = $A2; $file = DefaultFile $A3
    if (-not (Test-Path $file)) { '0'; break }
    (Section 'Review log' $file | Where-Object { $_ -match "loop=$loop .*kind=round" }).Count
  }
  'ship-red-count' {
    $file = DefaultFile $A2
    if (-not (Test-Path $file)) { '0'; break }
    $ns = Section 'Attempts' $file | ForEach-Object { if ($_ -match 'ATTEMPT ship-red — n=(\d+)') { [int]$matches[1] } }
    if ($ns) { $ns[-1] } else { '0' }
  }
  'ship-red-bump' {
    $file = DefaultFile $A2
    $cur = [int](& pwsh -NoProfile -File $PSCommandPath 'ship-red-count' $file)
    $next = $cur + 1
    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    if (-not (Test-Path $file)) { New-Item -ItemType File -Path $file | Out-Null }
    $line = "- ATTEMPT ship-red — n=$next — ts=$ts"
    $content = Get-Content -LiteralPath $file
    if ($content -contains '## Attempts') {
      $outLines = foreach ($l in $content) { $l; if ($l -eq '## Attempts') { $line } }
      Set-Content -LiteralPath $file -Value $outLines
    } else {
      Add-Content -LiteralPath $file -Value "`n## Attempts`n$line"
    }
    $next
  }
  default { [Console]::Error.WriteLine("goal-state: unknown subcommand '$Cmd'"); exit 3 }
}
```

- [ ] **Step 4: Run to verify parity**

Run: `node --test tools/test/goal-state.ps1.test.mjs` → PASS on a dual-runtime host.

- [ ] **Step 5: Commit**

```bash
git add src/shared/scripts/goal-state.ps1 tools/test/goal-state.ps1.test.mjs
git commit -m "feat(goal): goal-state.ps1 parity (section-scoped, exit 3)"
```

---

### Task 5: Verify CI auto-discovers the new tests (no CI edit expected)

**Files:** (verification only)

- [ ] **Step 1: Confirm CI uses Node test auto-discovery**

Run: `grep -n "node --test" .github/workflows/ci.yml`
Expected: Ubuntu job runs bare `node --test`, Windows job runs `node --test tools/test/` — **both
auto-discover** `tools/test/*.test.mjs`. The four new files are picked up with **no CI edit**.

- [ ] **Step 2: Confirm the whole suite is green locally**

Run: `npm run check`
Expected: lint + evals + `node --test` all green; the two `.ps1.test.mjs` SKIP if `pwsh` absent.

- [ ] **Step 3: (Conditional) commit only if CI actually changed**

CI needs no change, so there is nothing to commit here. Do **not** run an empty `git commit` (it
fails "nothing to commit"). If — and only if — a future CI refactor is required, make it a real
change and commit it; otherwise this task is a green-suite verification with no commit.

---

## Self-Review (rev2)

**Cross-engine plan-review findings (Opus + Codex) — disposition:**
- P1 digest not staging-invariant → **fixed**: temp-index `git add -N` normalization, one
  `git diff`, `--from-head` for the committed check; invariance test added (Task 1).
- P1 `grep -c` "0\n0" → **fixed**: `grep -c | head -1`; zero-count test added (Task 3).
- P1 Task-2 exclusion test wrote a non-excluded `docs` file → **fixed**: excluded path tested in
  isolation; positive control (`package.json` in scope) added (Task 1).
- P1 ps1 culture-sort / decoded-diff / `Get-Item` wildcards → **fixed by design**: ps1 hashes the
  raw bytes of the same `git diff` (no sort, no framing, no per-file read); `-LiteralPath` used in
  state.ps1; parity fixture includes mixed-case, non-ASCII, and `app/[id]/` (Task 2).
- P1 no pipefail / bad-base swallowed / missing-tool exit 3 → **fixed**: preflight git+sha+repo+base,
  git writes to a temp file whose status is the script's (Task 1); bad-base exit-3 test added.
- P1 `cat` symlink/`-n` → **fixed by design**: no `cat`; git frames symlinks as `120000`;
  symlink+leading-dash test added (Task 1).
- P1 reviewer/council scratch prefix unpinned → **resolved**: scratch lives under `.workflow/`
  (already excluded); documented in Global Constraints, no new prefix.
- P1 weak tests (rename = tracked mv; no positive controls) → **fixed**: invariance, package.json,
  symlink, exclusion-in-isolation, zero-count, section-scope, bump-parity, unknown-exit all added.
- P1 readers not section-scoped; bump appends at EOF → **fixed**: `section()` helper scopes every
  read; bump inserts right after `## Attempts`; DECOY-in-Notes test added (Task 3).
- P1 ps1 `Write-Error` exits 1 / cwd / native-error → **fixed**: `[Console]::Error.WriteLine`+`exit 3`,
  `Resolve-Path`, `$PSNativeCommandUseErrorActionPreference=$false` (Tasks 2, 4).
- P1 tests `new URL().pathname` / no `hasSh` → **fixed**: `fileURLToPath` + `hasSh`/`hasPwsh` guards
  everywhere.
- P1 Task 7 empty commit → **fixed**: Task 5 is verification-only, no commit unless CI truly changes.
- P2 `sort -z` non-POSIX → **moot**: the temp-index design removed the untracked `sort` entirely.

**Placeholder scan:** every step has complete runnable content; no TBD. (Task 1 Step 1 shows one
`execFileSync` stub then replaces it with the `spawnSync` exit-3 test — the final form is complete.)

**Type/name consistency:** subcommands (`field`/`round-count`/`ship-red-count`/`ship-red-bump`) and
the digest signature (`<base_sha> [repo_dir] [--from-head]`) are identical across `.sh`, `.ps1`, and
tests. The exclusion set is verbatim-identical in `goal-digest.sh`, `goal-digest.ps1`, and Global
Constraints.

**Deferred to Plan C (not Plan A):** the `field` **write** path and gate1/gate2/SIMPLIFY/blocker
writers, and the caller-side breaker comparison. Plan A ships only the read/count/digest/bump
primitives + the committed-tree digest mode those callers need.
