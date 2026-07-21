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

function assertExists(path) {
  if (!existsSync(path)) {
    throw new Error(`apply: ${path} not found — target not installed?`);
  }
}

// Replaces the body of a `## <heading>` section with `bodyText`, consuming
// ALL trailing content (including any number of trailing blank lines) up to
// the next top-level `## ` heading or end-of-file, and re-emitting a single
// canonical form that ends in exactly one trailing `\n` before whatever
// follows (or one trailing `\n` at end-of-file). This makes repeated calls
// with identical input byte-stable (idempotent), and — because the body is
// spliced in via plain string concatenation rather than String.replace's
// special replacement-pattern string — `$&`, `$$`, `` $` ``, `$'` etc. inside
// bodyText are inserted completely literally.
function replaceSection(md, heading, bodyText) {
  const startIdx = md.indexOf(heading);
  if (startIdx === -1) return md;
  const searchFrom = startIdx + heading.length;
  const rest = md.slice(searchFrom);
  const nextHeadingRel = rest.search(/\n## /);
  const endIdx = nextHeadingRel === -1 ? md.length : searchFrom + nextHeadingRel;
  const before = md.slice(0, startIdx);
  const after = md.slice(endIdx);
  return `${before}${heading}\n\n${bodyText}\n${after}`;
}

export function applyModels(targetDir, answers) {
  const path = join(targetDir, 'shared', 'rules', 'models.md');
  assertExists(path);
  const md = readFileSync(path, 'utf8');
  const re = new RegExp(`${START}[\\s\\S]*?${END}`);
  if (!re.test(md)) throw new Error('models.md is missing the managed review-policy block');
  // Replacer is a FUNCTION (not a string) so `$&`, `$$`, etc. in the
  // rendered block are inserted literally instead of being interpreted as
  // String.replace special replacement patterns.
  writeFileSync(path, md.replace(re, () => renderReviewBlock(answers)));
}

export function applyProfile(targetDir, answers) {
  const path = join(targetDir, 'shared', 'state.template.md');
  assertExists(path);
  if (!answers.profile) return;
  const md = readFileSync(path, 'utf8');
  writeFileSync(path, md.replace(/(\*\*Profile:\*\*\s*)([A-Za-z-]+)/, (_m, prefix) => `${prefix}${answers.profile}`));
}

export function applyProject(targetDir, answers) {
  const path = join(targetDir, 'PROJECT.md');
  assertExists(path);
  const p = answers.project || {};
  let md = readFileSync(path, 'utf8');
  if (p.rules && p.rules.trim()) {
    md = replaceSection(md, '## Special rules', p.rules.trim());
  }
  writeFileSync(path, md);
}

export function applyAll(targetDir, answers) {
  applyModels(targetDir, answers);
  applyProfile(targetDir, answers);
  applyProject(targetDir, answers);
}
