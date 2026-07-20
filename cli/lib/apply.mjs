// cli/lib/apply.mjs
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const START = '<!-- codeforge:review-policy:start -->';
const END = '<!-- codeforge:review-policy:end -->';

function renderReviewBlock(answers) {
  const lines = [START, '<!-- Managed by the codeforge setup wizard. Edit here or re-run the wizard. -->'];
  for (const r of answers.reviewers) {
    lines.push(`Reviewer — ${r.engine}: \`${r.model}\`${r.effort ? ` (${r.effort})` : ''}`);
  }
  lines.push(`Default reviewer(s): ${answers.defaultReviewer ?? answers.reviewers[0]?.engine ?? 'none'}`);
  lines.push(END);
  return lines.join('\n');
}

export function applyModels(targetDir, answers) {
  const path = join(targetDir, 'shared', 'rules', 'models.md');
  if (!existsSync(path)) return;
  const md = readFileSync(path, 'utf8');
  const re = new RegExp(`${START}[\\s\\S]*?${END}`);
  if (!re.test(md)) throw new Error('models.md is missing the managed review-policy block');
  writeFileSync(path, md.replace(re, renderReviewBlock(answers)));
}

export function applyProfile(targetDir, answers) {
  const path = join(targetDir, 'shared', 'state.template.md');
  if (!existsSync(path) || !answers.profile) return;
  const md = readFileSync(path, 'utf8');
  writeFileSync(path, md.replace(/(\*\*Profile:\*\*\s*)([A-Za-z-]+)/, `$1${answers.profile}`));
}

export function applyProject(targetDir, answers) {
  const path = join(targetDir, 'PROJECT.md');
  const p = answers.project || {};
  if (!existsSync(path)) return;
  let md = readFileSync(path, 'utf8');
  if (p.rules && p.rules.trim()) {
    md = md.replace(/## Special rules\n\n[\s\S]*?(?=\n## |\n*$)/,
      `## Special rules\n\n${p.rules.trim()}\n`);
  }
  writeFileSync(path, md);
}

export function applyAll(targetDir, answers) {
  applyModels(targetDir, answers);
  applyProfile(targetDir, answers);
  applyProject(targetDir, answers);
}
