# Interactive Setup Console (Ink TUI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a beautiful, default-on interactive setup console (Ink TUI) that detects engines, configures the default cross-engine review policy, and delegates the real install to `install.sh`/`install.ps1`.

**Architecture:** A new `cli/` package (Ink + React) is launched by `bin/codeforge.mjs` when stdin/stdout are a TTY and no install flags/target are passed. The wizard collects answers, spawns the existing shell installer, then applies configuration as idempotent post-install edits to the generated target files (`models.md`, `PROJECT.md`, `state.template.md`). Every answer has a non-interactive flag equivalent so CI/pipes and `--yes` bypass the UI.

**Tech Stack:** Node ≥20 (ESM `.mjs`), Ink 5, React 18, `ink-text-input`, `ink-select-input`, `node:test` + `ink-testing-library`. No TypeScript (repo is plain `.mjs`). Bash/PowerShell installer unchanged.

## Global Constraints

- Node engine floor: `>=20` (already in `package.json` `engines`) — copied verbatim.
- ESM only, `.mjs`, Node built-ins + declared deps; no bundler.
- npm package name is `@jualopezmo/codeforge`; installed CLI command is `codeforge`; brand/repo is `codeforge`.
- The clone `install.sh` path must remain dependency-free; only the wizard requires Node deps.
- Non-interactive behavior must be byte-for-byte unchanged when flags/target are passed or when stdin/stdout is not a TTY (CI, pipes) — the existing `tests/smoke.sh` "npx entry point" case must still pass.
- Wizard unit tests live under `tools/test/` (dev-only, NOT shipped) and import from `cli/`. Shipped code lives under `cli/` and is added to `package.json` `files[]`.
- Post-install edits are idempotent and marker-anchored; re-runs/`--upgrade` never corrupt target files.
- Model IDs may appear in the tool layer (`cli/`), not in `src/skills/*` (the skill-linter model-id quarantine is unaffected).
- Reviewer engine must differ from the driver (existing codeforge principle); the wizard surfaces this as guidance, not a hard block.

---

## File Structure

- `cli/index.mjs` — Ink app entry; exports `runWizard(pkgRoot)`.
- `cli/state.mjs` — the answers object shape + defaults (`makeDefaultAnswers`).
- `cli/lib/detect.mjs` — engine detection (`detectAll`).
- `cli/lib/models-catalog.json` — curated per-engine model/effort options + cost presets.
- `cli/lib/flags.mjs` — `hasInstallIntent(argv)`, `installerFlags(answers)`, `nonInteractiveCommand(answers)`.
- `cli/lib/apply.mjs` — `applyAll`, `applyModels`, `applyProject`, `applyProfile` (post-install edits).
- `cli/lib/run-installer.mjs` — `runInstaller(pkgRoot, opts, spawn?)`.
- `cli/assets/codeforge-icon.png` — committed source icon (1254×1254 pixel-art).
- `cli/assets/anvil.ans.mjs` — exports `{ theme, art }` (precomputed ANSI splash + hex palette).
- `cli/components/Splash.mjs`, `Detect.mjs`, `ReviewPolicy.mjs`, `Gates.mjs`, `Project.mjs`, `Summary.mjs`.
- `src/shared/rules/models.md` — add managed-block markers for `apply.mjs`.
- `bin/codeforge.mjs` — add the TTY→wizard branch.
- `tools/test/detect.test.mjs`, `flags.test.mjs`, `apply.test.mjs`, `run-installer.test.mjs`, `wizard-components.test.mjs`.
- `tests/smoke.sh` — add a non-TTY fallback assertion.
- `package.json`, `README.md`, `docs/CHANGELOG.md`.

---

### Task 1: Scaffold `cli/`, add deps, commit icon + ANSI splash asset

**Files:**
- Modify: `package.json` (dependencies + `files[]`)
- Create: `cli/assets/codeforge-icon.png` (copy from scratchpad)
- Create: `cli/assets/anvil.ans.mjs`
- Create: `cli/state.mjs`

**Interfaces:**
- Produces: `makeDefaultAnswers(cwd)` → answers object (see shape below); `theme` (hex palette), `art` (string) from `anvil.ans.mjs`.

Answers object shape (used by all later tasks):
```js
// { target: string,
//   reviewers: Array<{engine:'codex'|'claude'|'opencode', model:string, effort:string|null}>,
//   defaultReviewer: 'codex'|'claude'|'opencode'|null,
//   profile: 'standard'|'light',
//   withHooks: boolean, gitInit: boolean, noIsolate: boolean,
//   project: { persona: string, info: string, rules: string } }
```

- [ ] **Step 1: Add runtime deps and ship `cli/`**

Edit `package.json`: add to `files[]` the entry `"cli/"` (after `"bin/"`), and add a `dependencies` block:
```json
  "dependencies": {
    "ink": "^5.0.1",
    "react": "^18.3.1",
    "ink-text-input": "^6.0.0",
    "ink-select-input": "^6.0.0"
  },
```

- [ ] **Step 2: Install deps**

Run: `cd ~/Desktop/personal/projects/forge-ai && npm install`
Expected: `node_modules/` populated; `package-lock.json` created/updated; exit 0.

- [ ] **Step 3: Commit the icon PNG into the repo**

Run: `cp "/private/tmp/claude-501/-Users-juanmotta-Desktop-personal/b875d1c5-4ffc-4589-8550-0365e6ff1150/scratchpad/assets/codeforge-icon.png" cli/assets/codeforge-icon.png`
Expected: file exists at `cli/assets/codeforge-icon.png`.

- [ ] **Step 4: Generate ANSI splash (chafa if available) and write `anvil.ans.mjs`**

Try: `command -v chafa >/dev/null && chafa --format=symbols --colors=full --size=56x28 cli/assets/codeforge-icon.png` — capture output.
Write `cli/assets/anvil.ans.mjs`. If chafa produced art, paste it into the `art` template literal; otherwise use the fallback ASCII banner shown here (the wizard degrades gracefully — tests only assert non-empty):
```js
// Palette sampled from the codeforge anvil icon.
export const theme = {
  bg: '#0d1526',       // navy background
  steel: '#7f9bb3',    // anvil body
  steelDim: '#3f5globals'.replace('globals','a63'), // guard against copy typos; = '#3f5a63'
  molten: '#ff8a2b',   // incandescent orange (actions/accents)
  moltenHot: '#ffd23f',// hottest highlight
  cyan: '#39d7ff',     // </> / focus
  text: '#dbe4ee',
};
// `art` is a truecolor half-block string. When chafa is available at build time,
// replace the fallback below with its output for the pixel-art anvil.
export const art = process.env.CODEFORGE_NO_ART
  ? ''
  : String.raw`
        ${''}      </>
     _______________
    |###############|   c o d e f o r g e
    \_____________ /
      |         |
     /___________\
`;
```
Note: keep `theme` values plain hex; the `steelDim` line above intentionally shows the final value `#3f5a63` — write it directly as `steelDim: '#3f5a63',` (drop the `.replace` guard, it is only a reminder not to introduce typos).

- [ ] **Step 5: Create `cli/state.mjs`**

```js
import { basename } from 'node:path';

export function makeDefaultAnswers(cwd) {
  return {
    target: cwd,
    reviewers: [{ engine: 'codex', model: 'gpt-5.6-sol', effort: 'xhigh' }],
    defaultReviewer: 'codex',
    profile: 'standard',
    withHooks: false,
    gitInit: false,
    noIsolate: false,
    project: { persona: '', info: `Project: ${basename(cwd)}`, rules: '' },
  };
}
```

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json cli/assets/codeforge-icon.png cli/assets/anvil.ans.mjs cli/state.mjs
git commit -m "feat(cli): scaffold cli/ package, add ink deps, icon + splash asset"
```

---

### Task 2: Engine detection (`cli/lib/detect.mjs`)

**Files:**
- Create: `cli/lib/detect.mjs`
- Test: `tools/test/detect.test.mjs`

**Interfaces:**
- Produces: `detectAll(spawn?)` → `{ claude: Engine, codex: Engine, opencode: Engine }` where `Engine = { name, installed: boolean, version: string|null, hint: string }`. `spawn` defaults to a `node:child_process` `spawnSync` wrapper `(cmd, args) => ({ status, stdout })`; tests inject a fake.

- [ ] **Step 1: Write the failing test**

```js
// tools/test/detect.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { detectAll } from '../../cli/lib/detect.mjs';

function fakeSpawn(map) {
  return (cmd, args) => {
    const key = `${cmd} ${args.join(' ')}`;
    if (key in map) return map[key];
    return { status: 1, stdout: '' };
  };
}

test('detects an installed engine with version', () => {
  const spawn = fakeSpawn({ 'claude --version': { status: 0, stdout: '1.2.3\n' } });
  const r = detectAll(spawn);
  assert.equal(r.claude.installed, true);
  assert.equal(r.claude.version, '1.2.3');
});

test('reports a missing engine with an install hint', () => {
  const spawn = fakeSpawn({}); // nothing installed
  const r = detectAll(spawn);
  assert.equal(r.codex.installed, false);
  assert.equal(r.codex.version, null);
  assert.match(r.codex.hint, /install/i);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tools/test/detect.test.mjs`
Expected: FAIL — cannot find module `../../cli/lib/detect.mjs`.

- [ ] **Step 3: Write the implementation**

```js
// cli/lib/detect.mjs
import { spawnSync } from 'node:child_process';

const ENGINES = [
  { name: 'claude',   bin: 'claude',   hint: 'https://claude.com/claude-code' },
  { name: 'codex',    bin: 'codex',    hint: 'npm i -g @openai/codex' },
  { name: 'opencode', bin: 'opencode', hint: 'https://opencode.ai' },
];

function defaultSpawn(cmd, args) {
  const r = spawnSync(cmd, args, { encoding: 'utf8' });
  return { status: r.status ?? 1, stdout: r.stdout ?? '' };
}

function parseVersion(stdout) {
  const m = stdout.match(/\d+\.\d+(\.\d+)?/);
  return m ? m[0] : null;
}

export function detectAll(spawn = defaultSpawn) {
  const out = {};
  for (const e of ENGINES) {
    const r = spawn(e.bin, ['--version']);
    const installed = r.status === 0;
    out[e.name] = {
      name: e.name,
      installed,
      version: installed ? parseVersion(r.stdout) : null,
      hint: `install ${e.name}: ${e.hint}`,
    };
  }
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test tools/test/detect.test.mjs`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add cli/lib/detect.mjs tools/test/detect.test.mjs
git commit -m "feat(cli): engine detection with version + install hints"
```

---

### Task 3: Models catalog + flags mapping (`cli/lib/models-catalog.json`, `cli/lib/flags.mjs`)

**Files:**
- Create: `cli/lib/models-catalog.json`
- Create: `cli/lib/flags.mjs`
- Test: `tools/test/flags.test.mjs`

**Interfaces:**
- Consumes: answers shape (Task 1).
- Produces:
  - `hasInstallIntent(argv: string[])` → boolean (true when a target dir or any of `--upgrade/--with-hooks/--git-init/--no-isolate/--yes/--non-interactive` is present).
  - `installerFlags(answers)` → `string[]` (args for `install.sh`, e.g. `['/path', '--with-hooks']`).
  - `nonInteractiveCommand(answers)` → string (the reproducible `npx @jualopezmo/codeforge …` line).
  - `catalog` (default export of the JSON) → `{ codex:{default,cost,options[]}, claude:{…}, opencode:{…} }`.

- [ ] **Step 1: Write the failing test**

```js
// tools/test/flags.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { hasInstallIntent, installerFlags, nonInteractiveCommand } from '../../cli/lib/flags.mjs';
import { makeDefaultAnswers } from '../../cli/state.mjs';

test('hasInstallIntent is true for flags and targets, false for bare/--version', () => {
  assert.equal(hasInstallIntent(['--with-hooks']), true);
  assert.equal(hasInstallIntent(['./proj']), true);
  assert.equal(hasInstallIntent(['--yes']), true);
  assert.equal(hasInstallIntent([]), false);
  assert.equal(hasInstallIntent(['--version']), false);
  assert.equal(hasInstallIntent(['--help']), false);
});

test('installerFlags maps answers to install.sh args', () => {
  const a = { ...makeDefaultAnswers('/tmp/x'), withHooks: true, gitInit: true, noIsolate: false };
  assert.deepEqual(installerFlags(a), ['/tmp/x', '--with-hooks', '--git-init']);
});

test('nonInteractiveCommand is reproducible and includes reviewer + profile', () => {
  const a = { ...makeDefaultAnswers('/tmp/x'), profile: 'light' };
  const cmd = nonInteractiveCommand(a);
  assert.match(cmd, /npx @jualopezmo\/codeforge \/tmp\/x/);
  assert.match(cmd, /--yes/);
  assert.match(cmd, /--profile=light/);
  assert.match(cmd, /--reviewer=codex:gpt-5\.6-sol:xhigh/);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tools/test/flags.test.mjs`
Expected: FAIL — module not found.

- [ ] **Step 3: Write `models-catalog.json`**

```json
{
  "codex": {
    "default": { "model": "gpt-5.6-sol", "effort": "xhigh" },
    "cost": { "model": "gpt-5.4-mini", "effort": "high" },
    "options": [
      { "model": "gpt-5.6-sol", "effort": "xhigh" },
      { "model": "gpt-5.6-sol", "effort": "high" },
      { "model": "gpt-5.4-mini", "effort": "high" }
    ]
  },
  "claude": {
    "default": { "model": "opus", "effort": "high" },
    "cost": { "model": "sonnet", "effort": "high" },
    "options": [
      { "model": "opus", "effort": "high" },
      { "model": "sonnet", "effort": "high" },
      { "model": "haiku", "effort": "medium" }
    ]
  },
  "opencode": {
    "default": { "model": "opencode-go/glm-5.2", "effort": null },
    "cost": { "model": "opencode-go/deepseek-v4-flash", "effort": null },
    "options": [
      { "model": "opencode-go/glm-5.2", "effort": null },
      { "model": "opencode-go/kimi-k3", "effort": null },
      { "model": "opencode-go/deepseek-v4-flash", "effort": null }
    ]
  }
}
```

- [ ] **Step 4: Write `flags.mjs`**

```js
// cli/lib/flags.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
export const catalog = JSON.parse(readFileSync(join(here, 'models-catalog.json'), 'utf8'));

const INSTALL_FLAGS = new Set([
  '--upgrade', '--with-hooks', '--git-init', '--no-isolate', '--yes', '--non-interactive',
]);
const INFO_FLAGS = new Set(['--version', '-v', '--help', '-h']);

export function hasInstallIntent(argv) {
  for (const a of argv) {
    if (INFO_FLAGS.has(a)) return false;
  }
  return argv.some((a) => INSTALL_FLAGS.has(a) || !a.startsWith('-'));
}

export function installerFlags(answers) {
  const out = [answers.target];
  if (answers.withHooks) out.push('--with-hooks');
  if (answers.gitInit) out.push('--git-init');
  if (answers.noIsolate) out.push('--no-isolate');
  return out;
}

export function nonInteractiveCommand(answers) {
  const parts = ['npx @jualopezmo/codeforge', answers.target, '--yes'];
  if (answers.withHooks) parts.push('--with-hooks');
  if (answers.gitInit) parts.push('--git-init');
  if (answers.noIsolate) parts.push('--no-isolate');
  parts.push(`--profile=${answers.profile}`);
  for (const r of answers.reviewers) {
    parts.push(`--reviewer=${r.engine}:${r.model}${r.effort ? ':' + r.effort : ''}`);
  }
  if (answers.defaultReviewer) parts.push(`--default-reviewer=${answers.defaultReviewer}`);
  return parts.join(' ');
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `node --test tools/test/flags.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add cli/lib/models-catalog.json cli/lib/flags.mjs tools/test/flags.test.mjs
git commit -m "feat(cli): model catalog + answers→flags mapping"
```

---

### Task 4: Post-install applier (`cli/lib/apply.mjs`) + models.md markers

**Files:**
- Modify: `src/shared/rules/models.md` (add managed-block markers)
- Create: `cli/lib/apply.mjs`
- Test: `tools/test/apply.test.mjs`

**Interfaces:**
- Consumes: answers shape (Task 1).
- Produces: `applyAll(targetDir, answers)`; `applyModels(targetDir, answers)`; `applyProject(targetDir, answers)`; `applyProfile(targetDir, answers)`. All synchronous, idempotent, return nothing (throw on failure).

- [ ] **Step 1: Add managed-block markers to the shipped `models.md`**

In `src/shared/rules/models.md`, immediately below the `## Per-engine defaults` table, insert:
```markdown
<!-- codeforge:review-policy:start -->
<!-- Managed by the codeforge setup wizard. Edit here or re-run the wizard. -->
Default reviewer(s): Codex (`gpt-5.6-sol`, xhigh)
<!-- codeforge:review-policy:end -->
```

- [ ] **Step 2: Write the failing test**

```js
// tools/test/apply.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { applyModels, applyProfile, applyProject } from '../../cli/lib/apply.mjs';

function scaffoldTarget() {
  const dir = mkdtempSync(join(tmpdir(), 'cf-apply-'));
  mkdirSync(join(dir, 'shared', 'rules'), { recursive: true });
  writeFileSync(join(dir, 'shared', 'rules', 'models.md'),
    '# Models\n<!-- codeforge:review-policy:start -->\nDefault reviewer(s): OLD\n<!-- codeforge:review-policy:end -->\n');
  writeFileSync(join(dir, 'shared', 'state.template.md'), '- **Profile:** standard  <!-- comment -->\n');
  writeFileSync(join(dir, 'PROJECT.md'), '## Special rules\n\n_(fill in)_\n');
  return dir;
}

test('applyModels rewrites the managed block idempotently', () => {
  const dir = scaffoldTarget();
  const answers = { reviewers: [{ engine: 'codex', model: 'gpt-5.6-sol', effort: 'xhigh' }, { engine: 'opencode', model: 'opencode-go/kimi-k3', effort: null }], defaultReviewer: 'codex' };
  applyModels(dir, answers);
  applyModels(dir, answers); // idempotent
  const md = readFileSync(join(dir, 'shared', 'rules', 'models.md'), 'utf8');
  assert.match(md, /Default reviewer\(s\): codex/i);
  assert.match(md, /kimi-k3/);
  assert.equal(md.match(/review-policy:start/g).length, 1); // not duplicated
  assert.doesNotMatch(md, /OLD/);
});

test('applyProfile sets the profile in state.template.md', () => {
  const dir = scaffoldTarget();
  applyProfile(dir, { profile: 'light' });
  const md = readFileSync(join(dir, 'shared', 'state.template.md'), 'utf8');
  assert.match(md, /\*\*Profile:\*\* light/);
});

test('applyProject fills special rules when provided', () => {
  const dir = scaffoldTarget();
  applyProject(dir, { project: { persona: '', info: '', rules: 'Never touch prod.' } });
  const md = readFileSync(join(dir, 'PROJECT.md'), 'utf8');
  assert.match(md, /Never touch prod\./);
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `node --test tools/test/apply.test.mjs`
Expected: FAIL — module not found.

- [ ] **Step 4: Write `apply.mjs`**

```js
// cli/lib/apply.mjs
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const START = '<!-- codeforge:review-policy:start -->';
const END = '<!-- codeforge:review-policy:end -->';

function renderReviewBlock(answers) {
  const lines = [START, '<!-- Managed by the codeforge setup wizard. Edit here or re-run the wizard. -->'];
  for (const r of answers.reviewers) {
    lines.push(`Reviewer — ${r.engine}: \`${r.model}\`${r.effort ? ` (${r.effort})` : ''}`);
  }
  lines.push(`Default reviewer(s): ${answers.defaultReviewer ?? answers.reviewers[0]?.engine ?? 'none'}`);
  lines.push(END);
  return lines.join('\n');
}

export function applyModels(targetDir, answers) {
  const path = join(targetDir, 'shared', 'rules', 'models.md');
  if (!existsSync(path)) return;
  const md = readFileSync(path, 'utf8');
  const re = new RegExp(`${START}[\\s\\S]*?${END}`);
  if (!re.test(md)) throw new Error('models.md is missing the managed review-policy block');
  writeFileSync(path, md.replace(re, renderReviewBlock(answers)));
}

export function applyProfile(targetDir, answers) {
  const path = join(targetDir, 'shared', 'state.template.md');
  if (!existsSync(path) || !answers.profile) return;
  const md = readFileSync(path, 'utf8');
  writeFileSync(path, md.replace(/(\*\*Profile:\*\*\s*)([A-Za-z-]+)/, `$1${answers.profile}`));
}

export function applyProject(targetDir, answers) {
  const path = join(targetDir, 'PROJECT.md');
  const p = answers.project || {};
  if (!existsSync(path)) return;
  let md = readFileSync(path, 'utf8');
  if (p.rules && p.rules.trim()) {
    md = md.replace(/## Special rules\n\n[\s\S]*?(?=\n## |\n*$)/,
      `## Special rules\n\n${p.rules.trim()}\n`);
  }
  writeFileSync(path, md);
}

export function applyAll(targetDir, answers) {
  applyModels(targetDir, answers);
  applyProfile(targetDir, answers);
  applyProject(targetDir, answers);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `node --test tools/test/apply.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 6: Verify the skill-linter still passes (models.md markers don't break reference integrity)**

Run: `npm run lint:skills`
Expected: exit 0, no errors.

- [ ] **Step 7: Commit**

```bash
git add src/shared/rules/models.md cli/lib/apply.mjs tools/test/apply.test.mjs
git commit -m "feat(cli): idempotent post-install applier + models.md managed block"
```

---

### Task 5: Installer runner (`cli/lib/run-installer.mjs`)

**Files:**
- Create: `cli/lib/run-installer.mjs`
- Test: `tools/test/run-installer.test.mjs`

**Interfaces:**
- Consumes: `installerFlags(answers)` output (Task 3).
- Produces: `runInstaller(pkgRoot, argv, opts?)` where `argv` is the installer args array; `opts.platform` and `opts.spawn` are injectable for tests; returns `{ cmd, cmdArgs, status }`. Mirrors the logic already in `bin/codeforge.mjs` (bash vs pwsh + Windows flag translation) so both share one behavior.

- [ ] **Step 1: Write the failing test**

```js
// tools/test/run-installer.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runInstaller } from '../../cli/lib/run-installer.mjs';

test('POSIX runs bash install.sh with args verbatim', () => {
  const calls = [];
  const spawn = (cmd, args) => { calls.push([cmd, args]); return { status: 0 }; };
  const r = runInstaller('/pkg', ['/tmp/x', '--with-hooks'], { platform: 'linux', spawn });
  assert.equal(r.cmd, 'bash');
  assert.deepEqual(r.cmdArgs, ['/pkg/install.sh', '/tmp/x', '--with-hooks']);
  assert.equal(r.status, 0);
});

test('Windows runs pwsh install.ps1 with translated switches', () => {
  const spawn = () => ({ status: 0 });
  const r = runInstaller('C:\\pkg', ['C:\\x', '--with-hooks'], { platform: 'win32', spawn });
  assert.equal(r.cmd, 'pwsh');
  assert.ok(r.cmdArgs.includes('-WithHooks'));
  assert.ok(r.cmdArgs.some((a) => a.endsWith('install.ps1')));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tools/test/run-installer.test.mjs`
Expected: FAIL — module not found.

- [ ] **Step 3: Write `run-installer.mjs`**

```js
// cli/lib/run-installer.mjs
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';

const WIN_FLAG = { '--upgrade': '-Upgrade', '--with-hooks': '-WithHooks', '--git-init': '-GitInit', '--no-isolate': '-NoIsolate' };

function defaultSpawn(cmd, args) {
  const r = spawnSync(cmd, args, { stdio: 'inherit' });
  return { status: r.status ?? 1, error: r.error };
}

export function runInstaller(pkgRoot, argv, opts = {}) {
  const platform = opts.platform ?? process.platform;
  const spawn = opts.spawn ?? defaultSpawn;
  const isWin = platform === 'win32';
  const cmd = isWin ? 'pwsh' : 'bash';
  const cmdArgs = isWin
    ? ['-NoProfile', '-File', join(pkgRoot, 'install.ps1'), ...argv.map((a) => WIN_FLAG[a] ?? a)]
    : [join(pkgRoot, 'install.sh'), ...argv];
  const r = spawn(cmd, cmdArgs);
  return { cmd, cmdArgs, status: r.status ?? 1, error: r.error };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test tools/test/run-installer.test.mjs`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add cli/lib/run-installer.mjs tools/test/run-installer.test.mjs
git commit -m "feat(cli): installer runner (bash/pwsh) with injectable spawn"
```

---

### Task 6: Ink wizard — components + orchestration (`cli/components/*`, `cli/index.mjs`)

**Files:**
- Create: `cli/components/Splash.mjs`, `Detect.mjs`, `ReviewPolicy.mjs`, `Gates.mjs`, `Project.mjs`, `Summary.mjs`
- Create: `cli/index.mjs`
- Test: `tools/test/wizard-components.test.mjs`

**Interfaces:**
- Consumes: `detectAll` (T2), `catalog`/`nonInteractiveCommand` (T3), `makeDefaultAnswers`/`theme`/`art` (T1).
- Produces: `runWizard(pkgRoot)` → `Promise<answers|null>` (null if the user quits). Each component is `({ answers, setAnswers, onNext }) => JSX` (Ink elements via `React.createElement`; no JSX transform — use `html`-free `React.createElement` or the `htm` pattern is NOT added — write `createElement` directly to avoid a build step).

Because the repo has no JSX build step, components use `React.createElement` (aliased `e`). Steps show real code.

- [ ] **Step 1: Write the failing component test**

```js
// tools/test/wizard-components.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import React from 'react';
import { render } from 'ink-testing-library';
import Summary from '../../cli/components/Summary.mjs';
import { makeDefaultAnswers } from '../../cli/state.mjs';

test('Summary shows the reproducible non-interactive command', () => {
  const answers = { ...makeDefaultAnswers('/tmp/x'), profile: 'light' };
  const { lastFrame } = render(React.createElement(Summary, { answers, onNext: () => {} }));
  assert.match(lastFrame(), /npx @jualopezmo\/codeforge/);
  assert.match(lastFrame(), /--profile=light/);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tools/test/wizard-components.test.mjs`
Expected: FAIL — cannot find `../../cli/components/Summary.mjs`.

- [ ] **Step 3: Write `Summary.mjs`**

```js
// cli/components/Summary.mjs
import React from 'react';
import { Box, Text, useInput } from 'ink';
import { nonInteractiveCommand } from '../lib/flags.mjs';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Summary({ answers, onNext }) {
  useInput((input, key) => { if (key.return) onNext(true); if (input === 'q') onNext(false); });
  const cmd = nonInteractiveCommand(answers);
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, 'Review & confirm'),
    e(Text, null, `Target: ${answers.target}`),
    e(Text, null, `Profile: ${answers.profile}   Hooks: ${answers.withHooks ? 'yes' : 'no'}`),
    e(Text, null, `Default reviewer: ${answers.defaultReviewer ?? '(none)'}`),
    e(Box, { marginTop: 1, flexDirection: 'column' },
      e(Text, { color: theme.molten }, 'Reproducible (non-interactive):'),
      e(Text, { wrap: 'wrap' }, cmd)),
    e(Box, { marginTop: 1 }, e(Text, { dimColor: true }, 'Enter = install   q = cancel')));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test tools/test/wizard-components.test.mjs`
Expected: PASS.

- [ ] **Step 5: Write `Splash.mjs`**

```js
// cli/components/Splash.mjs
import React from 'react';
import { Box, Text, useInput } from 'ink';
import { art, theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Splash({ onNext, version }) {
  useInput((input, key) => { if (key.return || input === ' ') onNext(); });
  return e(Box, { flexDirection: 'column', alignItems: 'center', paddingY: 1 },
    art ? e(Text, null, art) : e(Text, { color: theme.steel }, '⚒  codeforge'),
    e(Text, { color: theme.cyan, bold: true }, `codeforge ${version ?? ''}`),
    e(Text, { dimColor: true }, 'cross-engine workflow discipline — press Enter to begin'));
}
```

- [ ] **Step 6: Write `Detect.mjs`**

```js
// cli/components/Detect.mjs
import React from 'react';
import { Box, Text, useInput } from 'ink';
import { detectAll } from '../lib/detect.mjs';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Detect({ onNext }) {
  const engines = React.useMemo(() => detectAll(), []);
  useInput((input, key) => { if (key.return) onNext(engines); });
  const rows = Object.values(engines).map((eng) =>
    e(Text, { key: eng.name, color: eng.installed ? theme.steel : undefined, dimColor: !eng.installed },
      `${eng.installed ? '✓' : '✗'} ${eng.name.padEnd(9)} ${eng.installed ? eng.version ?? 'installed' : eng.hint}`));
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, 'Engines detected'),
    e(Text, { dimColor: true }, 'You do NOT need all three — this just informs your review setup.'),
    e(Box, { flexDirection: 'column', marginTop: 1 }, ...rows),
    e(Box, { marginTop: 1 }, e(Text, { dimColor: true }, 'Enter = continue')));
}
```

- [ ] **Step 7: Write `ReviewPolicy.mjs`**

```js
// cli/components/ReviewPolicy.mjs
import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import { catalog } from '../lib/flags.mjs';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

// Pick the default reviewer engine, then its model. Non-driver engines only would be
// ideal, but the driver isn't known at install time, so we offer all catalog engines.
export default function ReviewPolicy({ answers, setAnswers, onNext }) {
  const [engine, setEngine] = React.useState(null);
  if (!engine) {
    const items = Object.keys(catalog).map((k) => ({ label: `Review by default with: ${k}`, value: k }));
    return e(Box, { flexDirection: 'column', paddingX: 1 },
      e(Text, { color: theme.cyan, bold: true }, 'Default review policy'),
      e(Text, { dimColor: true }, 'Which engine answers a bare "review"? (model next)'),
      e(SelectInput, { items, onSelect: (i) => setEngine(i.value) }));
  }
  const items = catalog[engine].options.map((o) => ({
    label: `${o.model}${o.effort ? ' · ' + o.effort : ''}`, value: o,
  }));
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, `Model for ${engine}`),
    e(SelectInput, { items, onSelect: (i) => {
      setAnswers({ ...answers, defaultReviewer: engine,
        reviewers: [{ engine, model: i.value.model, effort: i.value.effort }] });
      onNext();
    } }));
}
```

- [ ] **Step 8: Write `Gates.mjs`**

```js
// cli/components/Gates.mjs
import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Gates({ answers, setAnswers, onNext, engines }) {
  const claudeInstalled = engines?.claude?.installed;
  const items = [
    { label: 'Profile: standard (full gates)', value: { profile: 'standard' } },
    { label: 'Profile: light (quick-fix)', value: { profile: 'light' } },
  ];
  if (claudeInstalled) {
    items.push({ label: 'Also install the Claude hard-block hook (--with-hooks)', value: { withHooks: true } });
  }
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, 'Gates'),
    e(SelectInput, { items, onSelect: (i) => { setAnswers({ ...answers, ...i.value }); onNext(); } }));
}
```

- [ ] **Step 9: Write `Project.mjs`**

```js
// cli/components/Project.mjs
import React from 'react';
import { Box, Text } from 'ink';
import TextInput from 'ink-text-input';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Project({ answers, setAnswers, onNext }) {
  const [rules, setRules] = React.useState(answers.project.rules);
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, 'Project'),
    e(Text, null, `Target: ${answers.target}`),
    e(Box, { marginTop: 1 },
      e(Text, null, 'Special rules (optional): '),
      e(TextInput, { value: rules, onChange: setRules,
        onSubmit: () => { setAnswers({ ...answers, project: { ...answers.project, rules } }); onNext(); } })),
    e(Text, { dimColor: true }, 'Enter to continue'));
}
```

- [ ] **Step 10: Write `index.mjs` (orchestrator)**

```js
// cli/index.mjs
import React from 'react';
import { render, Box } from 'ink';
import { makeDefaultAnswers } from './state.mjs';
import Splash from './components/Splash.mjs';
import Detect from './components/Detect.mjs';
import ReviewPolicy from './components/ReviewPolicy.mjs';
import Gates from './components/Gates.mjs';
import Project from './components/Project.mjs';
import Summary from './components/Summary.mjs';

const e = React.createElement;
const STEPS = ['splash', 'detect', 'review', 'gates', 'project', 'summary'];

function Wizard({ pkgRoot, version, resolve }) {
  const [answers, setAnswers] = React.useState(makeDefaultAnswers(process.cwd()));
  const [engines, setEngines] = React.useState(null);
  const [i, setI] = React.useState(0);
  const next = () => setI((n) => Math.min(n + 1, STEPS.length - 1));
  const step = STEPS[i];
  let screen;
  if (step === 'splash') screen = e(Splash, { onNext: next, version });
  else if (step === 'detect') screen = e(Detect, { onNext: (eng) => { setEngines(eng); next(); } });
  else if (step === 'review') screen = e(ReviewPolicy, { answers, setAnswers, onNext: next });
  else if (step === 'gates') screen = e(Gates, { answers, setAnswers, engines, onNext: next });
  else if (step === 'project') screen = e(Project, { answers, setAnswers, onNext: next });
  else screen = e(Summary, { answers, onNext: (ok) => resolve(ok ? answers : null) });
  return e(Box, { flexDirection: 'column' }, screen);
}

export function runWizard(pkgRoot, version) {
  return new Promise((resolve) => {
    const { unmount } = render(e(Wizard, { pkgRoot, version, resolve: (a) => { unmount(); resolve(a); } }));
  });
}
```

- [ ] **Step 11: Run the full component test suite**

Run: `node --test tools/test/wizard-components.test.mjs`
Expected: PASS.

- [ ] **Step 12: Manual smoke of the UI (interactive)**

Run: `node -e "import('./cli/index.mjs').then(m=>m.runWizard(process.cwd(),'0.4.0')).then(a=>console.log('answers:',JSON.stringify(a)))"`
Expected: the wizard renders full-screen; navigating to Summary and pressing Enter prints the answers JSON; `q` on Summary prints `null`.

- [ ] **Step 13: Commit**

```bash
git add cli/components cli/index.mjs tools/test/wizard-components.test.mjs
git commit -m "feat(cli): Ink wizard screens + orchestration"
```

---

### Task 7: Wire the wizard into `bin/codeforge.mjs` + non-TTY fallback

**Files:**
- Modify: `bin/codeforge.mjs`
- Modify: `tests/smoke.sh` (add non-TTY fallback assertion)

**Interfaces:**
- Consumes: `hasInstallIntent` (T3), `runWizard` (T6), `installerFlags` (T3), `applyAll` (T4), `runInstaller` (T5).

- [ ] **Step 1: Rewrite the tail of `bin/codeforge.mjs`**

Replace lines 47–65 (the current `spawnSync` block) with:
```js
import { hasInstallIntent, installerFlags } from '../cli/lib/flags.mjs';
import { runInstaller } from '../cli/lib/run-installer.mjs';

const interactive = process.stdin.isTTY && process.stdout.isTTY && !hasInstallIntent(args);

if (interactive) {
  const { runWizard } = await import('../cli/index.mjs');
  const { applyAll } = await import('../cli/lib/apply.mjs');
  const answers = await runWizard(pkgRoot, version());
  if (!answers) { console.log('codeforge: setup cancelled.'); process.exit(0); }
  const r = runInstaller(pkgRoot, installerFlags(answers));
  if (r.status === 0) applyAll(answers.target, answers);
  process.exit(r.status);
} else {
  // Non-interactive (flags/target/CI/pipe): unchanged behavior — delegate straight to the installer.
  const r = runInstaller(pkgRoot, args);
  if (r.error) {
    const hint = process.platform === 'win32' ? 'PowerShell 7 (pwsh) is required on Windows.' : '';
    console.error(`codeforge: could not launch ${r.cmd}: ${r.error.message}. ${hint}`.trim());
    process.exit(1);
  }
  process.exit(r.status ?? 1);
}
```
Also add `import { spawnSync }`-removal: the old inline spawn is now in `run-installer.mjs`; delete the now-unused `spawnSync`/`platform` imports at the top (keep `readFileSync`, `join`, `dirname`, `fileURLToPath`). The file must remain top-level `await`-capable — Node runs `.mjs` as a module, so top-level `await` is allowed.

- [ ] **Step 2: Add the non-TTY fallback smoke case**

In `tests/smoke.sh`, after the existing npx case (line ~225), before `echo "ALL PASS"`, add:
```bash
# --- 17. the npx entry point stays non-interactive when stdin/stdout are not a TTY ---
if command -v node >/dev/null 2>&1; then
  TX2="$TMP/npx-notty"; mkdir -p "$TX2"
  node "$ROOT/bin/codeforge.mjs" "$TX2" </dev/null >/dev/null 2>&1 || fail "npx non-TTY install exited non-zero"
  [ -f "$TX2/CLAUDE.md" ] || fail "npx non-TTY did not fall back to install (no CLAUDE.md)"
  echo "ok: npx entry point stays non-interactive without a TTY"
fi
```

- [ ] **Step 3: Run the smoke test**

Run: `bash tests/smoke.sh`
Expected: `ALL PASS`, including the new "stays non-interactive without a TTY" line. (The wizard branch is skipped because a piped `</dev/null` makes `process.stdin.isTTY` falsy AND a target arg triggers `hasInstallIntent`.)

- [ ] **Step 4: Run the full check**

Run: `npm run check`
Expected: lint + evals + all `node --test` files pass (0 failures), including the new cli tests.

- [ ] **Step 5: Commit**

```bash
git add bin/codeforge.mjs tests/smoke.sh
git commit -m "feat(cli): launch wizard on TTY, keep non-interactive fallback"
```

---

### Task 8: Docs, CHANGELOG, packaging verification

**Files:**
- Modify: `README.md` (install section + a "Interactive setup" subsection)
- Modify: `docs/CHANGELOG.md` (Unreleased entry)
- Verify: `package.json` `files[]` ships `cli/`; dry-run tarball includes `cli/` and excludes `tools/`.

- [ ] **Step 1: Add a README subsection under Installation**

Insert after the `### Fastest — npx` block:
```markdown
### Interactive setup (default)

Run with no arguments in a terminal and codeforge opens a full-screen setup console:

​```bash
npx @jualopezmo/codeforge          # opens the interactive wizard
​```

It detects which engines you have (Claude / Codex / OpenCode — you don't need all
three), lets you set the **default review policy** (which engine + model answers a bare
"review"), the gate profile, and project options, then runs the installer. Pass any flag
(or run without a TTY, e.g. in CI) to skip the UI and install non-interactively; the
wizard's summary prints the exact non-interactive command it would run.
```

- [ ] **Step 2: Add the CHANGELOG entry**

Under `## Unreleased` (create it above `## 0.4.0`):
```markdown
## Unreleased

- **Interactive setup console (Ink TUI).** `npx @jualopezmo/codeforge` with no args on a
  TTY now opens a full-screen wizard: engine detection, default review-policy configuration
  (written to `shared/rules/models.md`), gate profile, and project options. Delegates to
  `install.sh`/`install.ps1` and applies config as idempotent post-install edits. Falls back
  to the non-interactive installer when flags are passed or there is no TTY (CI/pipes). Adds
  `ink`/`react` as runtime deps (the clone `install.sh` path stays dependency-free).
```

- [ ] **Step 3: Verify the tarball**

Run: `npm publish --dry-run 2>&1 | grep -E "cli/|tools/" | head`
Expected: `cli/…` entries present; NO `tools/…` entries (dev-only).

- [ ] **Step 4: Final full check**

Run: `npm run check && bash tests/smoke.sh`
Expected: all green; `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/CHANGELOG.md
git commit -m "docs: document the interactive setup console"
```

---

## Self-Review

**Spec coverage:**
- Default-on interactive UI → Task 7 (TTY branch) ✓
- Engine detection (informational) → Task 2 + `Detect.mjs` (T6) ✓
- Default review policy in models.md → Task 3 (catalog), Task 4 (applier + markers), `ReviewPolicy.mjs` (T6) ✓
- Gates profile + hooks → Task 4 (applyProfile), `Gates.mjs` (T6), `installerFlags` (T3) ✓
- Project + git + isolation → Task 3 (flags), Task 4 (applyProject), `Project.mjs` (T6) ✓
- Delegate to install.sh + post-install edits → Task 5 + Task 7 ✓
- Non-interactive parity → Task 3 (`nonInteractiveCommand`, `hasInstallIntent`) + Task 7 fallback + Task 7 smoke case ✓
- Splash + theme from icon → Task 1 (`anvil.ans.mjs`) + `Splash.mjs` (T6) ✓
- Testing → tools/test/* (T2–T6) + smoke (T7) ✓
- Runtime dep documented → Task 1 + Task 8 CHANGELOG ✓

**Type/name consistency:** answers shape defined in T1 `makeDefaultAnswers` and consumed identically in T3/T4/T6/T7; `runInstaller(pkgRoot, argv, opts)` signature consistent T5↔T7; `installerFlags`/`hasInstallIntent`/`nonInteractiveCommand` names consistent T3↔T7; `applyAll(targetDir, answers)` consistent T4↔T7.

**Placeholder scan:** every code step contains real code; the only intentional variability is `anvil.ans.mjs`'s `art` (chafa output vs the committed fallback banner) — both are concrete and the wizard/tests handle either.

**Open items deferred to implementation (from the spec, acceptable):** exact chafa availability for splash art (fallback provided), Windows PTY key-handling verification (manual, Task 6 Step 12 on Windows).
