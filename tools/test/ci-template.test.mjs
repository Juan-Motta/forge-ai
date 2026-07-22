import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const gates = readFileSync(join(repoRoot, 'src', 'docs', 'ci-templates', 'gates.yml'), 'utf8');
const readme = readFileSync(join(repoRoot, 'src', 'docs', 'ci-templates', 'README.md'), 'utf8');

test('gates.yml triggers on pull_request', () => {
  assert.match(gates, /^on:\s*[\s\S]*pull_request:/m);
});

test('gates.yml checks out the code (merge result) via actions/checkout', () => {
  assert.match(gates, /actions\/checkout@v\d/);
});

test('gates.yml default test step is the fail-closed sentinel (exit 1)', () => {
  // An un-edited required check must FAIL, not pass green while running nothing.
  assert.match(gates, /exit 1/);
});

test('README documents required-check + do-not-allow-bypassing', () => {
  assert.match(readme, /required status check/i);
  assert.match(readme, /do not allow bypassing/i);
});
