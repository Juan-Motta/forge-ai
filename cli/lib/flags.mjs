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

export default catalog;
