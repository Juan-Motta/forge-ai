#!/usr/bin/env node
// lint-skills — CLI wrapper around tools/lib/skill-lint.mjs.
// Walks src/skills/, runs the linter, prints a report, exits 1 on any error.
//
//   node tools/lint-skills.mjs            # lint this repo's src/skills
//   node tools/lint-skills.mjs --quiet    # errors only, no warnings

import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { lintSkills } from './lib/skill-lint.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..');
const srcDir = join(repoRoot, 'src');

const quiet = process.argv.includes('--quiet');

const { results, totalErrors, totalWarnings } = lintSkills({
  skillsDir: join(srcDir, 'skills'),
  claudeMd: join(srcDir, 'CLAUDE.md'),
  srcDir,
});

for (const r of results) {
  if (r.errors.length === 0 && r.warnings.length === 0) {
    console.log(`  ✓  ${r.skill}`);
    continue;
  }
  const icon = r.errors.length > 0 ? '  ✗ ' : '  ⚠ ';
  console.log(`${icon} ${r.skill}`);
  for (const m of r.errors) console.log(`       ERROR: ${m}`);
  if (!quiet) for (const m of r.warnings) console.log(`       WARN:  ${m}`);
}

const status = totalErrors > 0 ? 'FAILED' : totalWarnings > 0 ? 'PASSED WITH WARNINGS' : 'PASSED';
const shown = quiet ? `${totalErrors} error(s)` : `${totalErrors} error(s), ${totalWarnings} warning(s)`;
console.log(`\n${results.length} entries checked — ${shown} — ${status}`);

process.exit(totalErrors > 0 ? 1 : 0);
