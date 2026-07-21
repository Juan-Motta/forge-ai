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
