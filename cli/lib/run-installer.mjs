import { spawnSync } from 'node:child_process';
import { posix, win32 } from 'node:path';

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
  // Build the installer path with the join that matches the TARGET platform (not the host),
  // so an injected `platform` yields deterministic separators cross-OS (fixes Windows CI).
  const cmdArgs = isWin
    ? ['-NoProfile', '-File', win32.join(pkgRoot, 'install.ps1'), ...argv.map((a) => WIN_FLAG[a] ?? a)]
    : [posix.join(pkgRoot, 'install.sh'), ...argv];
  const r = spawn(cmd, cmdArgs);
  return { cmd, cmdArgs, status: r.status ?? 1, error: r.error };
}
