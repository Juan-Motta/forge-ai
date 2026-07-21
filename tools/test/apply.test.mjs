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

test('applyProject is idempotent across repeated calls with identical answers', () => {
  const dir = scaffoldTarget();
  const answers = { project: { persona: '', info: '', rules: 'Never touch prod.' } };
  applyProject(dir, answers);
  applyProject(dir, answers);
  const afterRun2 = readFileSync(join(dir, 'PROJECT.md'), 'utf8');
  applyProject(dir, answers);
  const afterRun3 = readFileSync(join(dir, 'PROJECT.md'), 'utf8');
  assert.equal(afterRun2, afterRun3);
  assert.equal(afterRun3, '## Special rules\n\nNever touch prod.\n');
});

test('applyProject inserts rules text containing literal replacement tokens verbatim', () => {
  const dir = scaffoldTarget();
  const tricky = 'Refund rule: give $1 credit, never $& the balance, escape $$ signs.';
  applyProject(dir, { project: { persona: '', info: '', rules: tricky } });
  const md = readFileSync(join(dir, 'PROJECT.md'), 'utf8');
  assert.ok(md.includes(tricky), 'tricky replacement-token content should appear verbatim');
});

test('applyModels throws when the target file does not exist', () => {
  const dir = mkdtempSync(join(tmpdir(), 'cf-apply-missing-'));
  const answers = { reviewers: [{ engine: 'codex', model: 'gpt-5.6-sol', effort: 'xhigh' }], defaultReviewer: 'codex' };
  assert.throws(() => applyModels(dir, answers), /not found/);
});
