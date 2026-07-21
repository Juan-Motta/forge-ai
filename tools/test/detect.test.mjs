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
