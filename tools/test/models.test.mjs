import { test } from 'node:test';
import assert from 'node:assert/strict';
import { optionsFor } from '../../cli/lib/models.mjs';

test('opencode: parses the live `opencode models` list', () => {
  const spawn = (cmd, args) => {
    assert.equal(cmd, 'opencode');
    assert.deepEqual(args, ['models']);
    return { status: 0, stdout: 'opencode-go/glm-5.2\nopencode-go/kimi-k3\n\n' };
  };
  const opts = optionsFor('opencode', spawn);
  assert.deepEqual(opts, [
    { model: 'opencode-go/glm-5.2', effort: null },
    { model: 'opencode-go/kimi-k3', effort: null },
  ]);
});

test('opencode: falls back to the curated catalog when the CLI is unavailable', () => {
  const spawn = () => ({ status: 1, stdout: '' });
  const opts = optionsFor('opencode', spawn);
  assert.ok(opts.length > 0);
  assert.ok(opts.every((o) => 'model' in o));
});

test('codex/claude: use the curated catalog (no CLI listing exists)', () => {
  let called = false;
  const spawn = () => { called = true; return { status: 0, stdout: '' }; };
  const codex = optionsFor('codex', spawn);
  const claude = optionsFor('claude', spawn);
  assert.equal(called, false, 'must not spawn any CLI for codex/claude');
  assert.ok(codex.some((o) => o.model === 'gpt-5.6-sol'));
  assert.ok(claude.some((o) => o.model === 'opus'));
});
