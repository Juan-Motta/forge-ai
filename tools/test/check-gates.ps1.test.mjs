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

test('ps1 parity: report FIRST verdict is FAIL but a LATER per-UC line is VERDICT: PASS → exit 1', { skip: !hasPwsh }, () => {
  // Mirrors check-gates.sh test 'j' — the gate must anchor to the TOP-LEVEL (first)
  // VERDICT line, not match any VERDICT: PASS line anywhere in the file.
  const box = '- [x] E2E verified via verify-e2e (report: docs/e2e/reports/r.md)';
  const d = make(box, 'VERDICT: FAIL\n\nSome narrative text.\n\n## Per-UC results\nUC1: login flow\nVERDICT: PASS\n');
  assert.equal(run(d), 1);
  rmSync(d, { recursive: true, force: true });
});

test('ps1 parity: box checked + report git-add STAGED (not committed) on branch + PASS → exit 0', { skip: !hasPwsh }, () => {
  // Mirrors check-gates.sh test 'i' — a report `git add`-ed but not yet committed is the
  // natural post-verify-e2e state before the human runs `git commit`. Must be treated as
  // fresh, same as untracked/committed, on both sh and ps1.
  const dir = mkdtempSync(join(tmpdir(), 'cgps-'));
  git(dir, 'init', '-q', '-b', 'main');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  writeFileSync(join(dir, 'seed'), 'x');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed');
  git(dir, 'checkout', '-q', '-b', 'feat/x');
  mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
  writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'r.md'), 'VERDICT: PASS\n');
  git(dir, 'add', 'docs/e2e/reports/r.md');
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
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});
