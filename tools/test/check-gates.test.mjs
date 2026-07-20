import { test as _test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const script = join(repoRoot, 'src', 'shared', 'scripts', 'check-gates.sh');

// The sh script needs a POSIX shell. On Windows CI (where `node --test tools/test/`
// runs so the .ps1 parity tests execute under pwsh) `sh` may be absent — skip
// gracefully, mirroring the .ps1 test's `hasPwsh` guard, rather than hard-failing.
let hasSh = true;
try { execFileSync('sh', ['-c', 'exit 0'], { stdio: 'pipe' }); } catch { hasSh = false; }
const test = (name, fn) => _test(name, hasSh ? {} : { skip: true }, fn);

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

test('g: no base resolves (default branch), named report PRESENT + PASS → exit 0 (freshness skipped, existence+PASS enforced)', () => {
  // On the only branch (main): main == current so it is skipped, no dev/master/origin →
  // base unresolved. Freshness cannot be checked, but existence + top-level PASS still are.
  const dir = setup({ report: 'VERDICT: PASS\n', onDefaultBranch: true });
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});

test('h: old 6-box state without E2E box name still passes count, unaffected → exit 0', () => {
  const dir = setup({ box: '- [x] Change verified by exercising it', report: undefined });
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});

test('j: report FIRST verdict is FAIL but a LATER per-UC line is VERDICT: PASS → exit 1', () => {
  // Proves Fix 1: the gate must anchor to the TOP-LEVEL (first) VERDICT line, not match
  // any VERDICT: PASS line anywhere in the file. A per-UC block below a top-level FAIL
  // must never satisfy the gate.
  const dir = setup({
    report: 'VERDICT: FAIL\n\nSome narrative text.\n\n## Per-UC results\nUC1: login flow\nVERDICT: PASS\n',
  });
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});

test('k: E2E box line copied from the ship-gates.md doc text (no real N/A escape) + placeholder → exit 1', () => {
  // Proves the doc line in ship-gates.md contains the substring "N/A:" inside backticked
  // explanatory text ("— `N/A: <reason>` allowed for ...") but NOT the real escape form
  // "— N/A:" (em-dash, space, N/A:, no backtick). If a user mis-copies that doc line into
  // state.md and checks it, the gate must NOT treat it as an N/A skip — it falls through
  // and is rejected as a placeholder report path (`<...>`).
  const dir = setup({
    box: '- [x] E2E verified via verify-e2e (report: docs/e2e/reports/<...>.md) — `N/A: <reason>` allowed for purely internal changes (migration, refactor, tooling) and UI-only changes (no v1 adapter)',
    report: undefined,
  });
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});

test('i: box checked + report git-add STAGED (not committed) on branch + PASS → exit 0', () => {
  // Report is `git add`-staged but not committed — the natural post-verify-e2e workflow
  // before the human runs `git commit`. Must be treated as fresh, same as untracked/committed.
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
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

test('l: named-path mismatch — box names an ABSENT report while an UNRELATED fresh PASS exists → exit 1', () => {
  // Closes the "any report" hole: the box names feat.md (which does NOT exist) but an
  // unrelated fresh PASS report other.md DOES exist. The old code scanned the whole
  // reports dir and would pass on other.md; the named-path gate must fail.
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
  git(dir, 'init', '-q', '-b', 'main');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  writeFileSync(join(dir, 'seed'), 'x');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed');
  git(dir, 'checkout', '-q', '-b', 'feat/x');
  mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
  writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'other.md'), 'VERDICT: PASS\n');
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'),
`## Active workflow
- **Profile:** standard
## Ship-gate checklist
- [x] a
- [x] b
- [x] c
- [x] d
- [x] E2E verified via verify-e2e (report: docs/e2e/reports/feat.md)
- [x] f
`);
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});

test('m: placeholder report path rejected even when an unrelated fresh PASS exists → exit 1', () => {
  // The box still carries the `<...>` placeholder. The old code would pass on the unrelated
  // fresh PASS report present in the dir; the named-path gate must reject the placeholder.
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
  git(dir, 'init', '-q', '-b', 'main');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  writeFileSync(join(dir, 'seed'), 'x');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed');
  git(dir, 'checkout', '-q', '-b', 'feat/x');
  mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
  writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'other.md'), 'VERDICT: PASS\n');
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'),
`## Active workflow
- **Profile:** standard
## Ship-gate checklist
- [x] a
- [x] b
- [x] c
- [x] d
- [x] E2E verified via verify-e2e (report: docs/e2e/reports/<...>.md)
- [x] f
`);
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});

test('n: named report committed on the feature branch (base = main) + PASS → exit 0', () => {
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
  git(dir, 'init', '-q', '-b', 'main');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  writeFileSync(join(dir, 'seed'), 'x');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed');
  git(dir, 'checkout', '-q', '-b', 'feat/x');
  mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
  writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'feat.md'), 'VERDICT: PASS\n');
  git(dir, 'add', 'docs/e2e/reports/feat.md'); git(dir, 'commit', '-qm', 'e2e report');
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'),
`## Active workflow
- **Profile:** standard
## Ship-gate checklist
- [x] a
- [x] b
- [x] c
- [x] d
- [x] E2E verified via verify-e2e (report: docs/e2e/reports/feat.md)
- [x] f
`);
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});

test('o: dev-based branch — a PASS report inherited on dev cannot satisfy the box that names THIS feature report → exit 1', () => {
  // Repo has main + dev. dev carries an inherited PASS report at a DIFFERENT path.
  // The feature branch forks from dev; its box names feat.md, which is absent. Closest
  // merge-base is dev, and the dev-inherited report is not the named one → exit 1.
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
  git(dir, 'init', '-q', '-b', 'main');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  writeFileSync(join(dir, 'seed'), 'x');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed');
  git(dir, 'checkout', '-q', '-b', 'dev');
  mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
  writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'inherited.md'), 'VERDICT: PASS\n');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'dev inherited report');
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
- [x] E2E verified via verify-e2e (report: docs/e2e/reports/feat.md)
- [x] f
`);
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});

test('p: named report committed on base then edited unstaged on branch → fresh via unstaged edit → exit 0', () => {
  // Report committed on main (base), then edited (unstaged) on the feature branch. It is
  // not committed/staged on the branch, but the unstaged tracked edit makes it fresh.
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
  git(dir, 'init', '-q', '-b', 'main');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
  writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'feat.md'), 'VERDICT: FAIL\n');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed+report');
  git(dir, 'checkout', '-q', '-b', 'feat/x');
  // Unstaged edit on the branch flips it to PASS.
  writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'feat.md'), 'VERDICT: PASS\n');
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'),
`## Active workflow
- **Profile:** standard
## Ship-gate checklist
- [x] a
- [x] b
- [x] c
- [x] d
- [x] E2E verified via verify-e2e (report: docs/e2e/reports/feat.md)
- [x] f
`);
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});

test('q: no-base fail-safe — single branch (no main/master/dev), named report PRESENT + PASS → exit 0 with freshness note', () => {
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
  git(dir, 'init', '-q', '-b', 'feat/solo');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  writeFileSync(join(dir, 'seed'), 'x');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed');
  mkdirSync(join(dir, 'docs', 'e2e', 'reports'), { recursive: true });
  writeFileSync(join(dir, 'docs', 'e2e', 'reports', 'feat.md'), 'VERDICT: PASS\n');
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'),
`## Active workflow
- **Profile:** standard
## Ship-gate checklist
- [x] a
- [x] b
- [x] c
- [x] d
- [x] E2E verified via verify-e2e (report: docs/e2e/reports/feat.md)
- [x] f
`);
  assert.equal(run(dir), 0);
  rmSync(dir, { recursive: true, force: true });
});

test('r: no-base fail-safe — single branch, named report ABSENT → exit 1 (never fail open)', () => {
  const dir = mkdtempSync(join(tmpdir(), 'cg-'));
  git(dir, 'init', '-q', '-b', 'feat/solo');
  git(dir, 'config', 'user.email', 't@t'); git(dir, 'config', 'user.name', 't');
  writeFileSync(join(dir, 'seed'), 'x');
  git(dir, 'add', '.'); git(dir, 'commit', '-qm', 'seed');
  mkdirSync(join(dir, '.workflow'), { recursive: true });
  writeFileSync(join(dir, '.workflow', 'state.md'),
`## Active workflow
- **Profile:** standard
## Ship-gate checklist
- [x] a
- [x] b
- [x] c
- [x] d
- [x] E2E verified via verify-e2e (report: docs/e2e/reports/feat.md)
- [x] f
`);
  assert.equal(run(dir), 1);
  rmSync(dir, { recursive: true, force: true });
});
