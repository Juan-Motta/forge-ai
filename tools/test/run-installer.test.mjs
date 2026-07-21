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
