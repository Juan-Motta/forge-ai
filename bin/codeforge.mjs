#!/usr/bin/env node
// codeforge — npx entry point. Thin wrapper that runs the platform installer
// bundled in this package (install.sh on POSIX, install.ps1 on Windows),
// passing through all arguments. The payload (src/, VERSION) travels in the
// package, so `npx @jualopezmo/codeforge [target] [--upgrade]` works with no repo clone.
//
//   npx @jualopezmo/codeforge                 # install into the current directory
//   npx @jualopezmo/codeforge ./my-project    # install into a target
//   npx @jualopezmo/codeforge --upgrade       # refresh an existing install
//   npx @jualopezmo/codeforge --version       # print the codeforge version

import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readFileSync } from 'node:fs';
import { platform } from 'node:os';

const pkgRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);

function version() {
  try {
    return readFileSync(join(pkgRoot, 'VERSION'), 'utf8').trim() || 'unknown';
  } catch {
    return 'unknown';
  }
}

if (args.includes('--version') || args.includes('-v')) {
  console.log(version());
  process.exit(0);
}
if (args.includes('--help') || args.includes('-h')) {
  console.log(`codeforge ${version()} — install the cross-engine workflow discipline into a project.

  npx @jualopezmo/codeforge [target-dir] [--upgrade] [--with-hooks] [--git-init] [--no-isolate]

  target-dir    where to install (default: current directory)
  --upgrade     refresh framework files in an existing install
  --with-hooks  also install the opt-in Claude Code hard-block gate hook (Claude only)
  --git-init    if the target is not a git repo, initialize one + baseline commit
  --no-isolate  keep inheriting ancestor CLAUDE.md (default: auto-isolate via claudeMdExcludes)
  --version     print the codeforge version`);
  process.exit(0);
}

const isWin = platform() === 'win32';
// Windows: install.ps1 declares PowerShell switches (-Upgrade, ...), not POSIX long-flags,
// so translate them; an unmapped arg (e.g. the target dir) passes through untouched.
const winFlag = { '--upgrade': '-Upgrade', '--with-hooks': '-WithHooks', '--git-init': '-GitInit', '--no-isolate': '-NoIsolate' };
// POSIX: run with `bash`, NOT `sh` — install.sh uses `set -o pipefail`, which dash (the /bin/sh
// on Debian/Ubuntu) does not support, so `sh install.sh` would abort immediately.
const cmd = isWin ? 'pwsh' : 'bash';
const cmdArgs = isWin
  ? ['-NoProfile', '-File', join(pkgRoot, 'install.ps1'), ...args.map((a) => winFlag[a] ?? a)]
  : [join(pkgRoot, 'install.sh'), ...args];

const r = spawnSync(cmd, cmdArgs, { stdio: 'inherit' });
if (r.error) {
  const hint = isWin ? 'PowerShell 7 (pwsh) is required on Windows.' : '';
  console.error(`codeforge: could not launch ${cmd}: ${r.error.message}. ${hint}`.trim());
  process.exit(1);
}
process.exit(r.status ?? 1);
