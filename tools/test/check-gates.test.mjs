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
