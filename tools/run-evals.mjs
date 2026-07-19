#!/usr/bin/env node
// run-evals — deterministic routing/collision evals over the skill catalog.
//
//   node tools/run-evals.mjs                 # report + enforce defaults
//   node tools/run-evals.mjs --min-rank1 80  # raise the rank-1 floor
//   node tools/run-evals.mjs --quiet         # summary only
//
// Fails (exit 1) on: a skill with no eval case (coverage), a positive prompt
// whose owner falls outside top_k, a negative prompt whose owner does not
// outrank the sibling, a description collision at/above the error threshold, or
// a rank-1 rate below the floor.

import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { buildCorpus, rankSkills, rankOf, collisions } from './lib/routing.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..');
const skillsDir = join(repoRoot, 'src', 'skills');
const casesPath = join(here, 'evals', 'routing-cases.json');

const argv = process.argv.slice(2);
const quiet = argv.includes('--quiet');
const minRank1 = num('--min-rank1', 70);
const collideErrorAt = num('--collision-error', 0.75);

function num(flag, dflt) {
  const i = argv.indexOf(flag);
  return i >= 0 && argv[i + 1] ? Number(argv[i + 1]) : dflt;
}

// --- Load skill descriptions (the routing corpus) ---
function descriptionOf(skillDir) {
  const p = join(skillsDir, skillDir, 'SKILL.md');
  if (!existsSync(p)) return null;
  const m = readFileSync(p, 'utf8').match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return null;
  const d = m[1].match(/^description:\s*(.*)$/m);
  return d ? d[1].trim() : null;
}

const skillNames = readdirSync(skillsDir)
  .filter((d) => statSync(join(skillsDir, d)).isDirectory())
  .sort();

const docs = [];
for (const name of skillNames) {
  const desc = descriptionOf(name);
  if (desc) docs.push({ name, text: desc });
}
const corpus = buildCorpus(docs);

const cases = JSON.parse(readFileSync(casesPath, 'utf8')).skills || {};

let errors = 0;
let rank1Hits = 0;
let positives = 0;
const failLines = [];

// --- Coverage: every skill needs an eval entry ---
for (const name of skillNames) {
  if (!cases[name]) { errors++; failLines.push(`COVERAGE: skill "${name}" has no eval case`); }
}
for (const name of Object.keys(cases)) {
  if (!skillNames.includes(name)) { errors++; failLines.push(`COVERAGE: eval case "${name}" has no skill dir`); }
}

// --- Positive & negative routing ---
for (const [owner, spec] of Object.entries(cases)) {
  for (const item of spec.positive || []) {
    const prompt = typeof item === 'string' ? item : item.prompt;
    const topK = (typeof item === 'object' && item.top_k) || 3;
    positives++;
    const ranked = rankSkills(prompt, corpus);
    const pos = ranked.findIndex((r) => r.name === owner) + 1;
    if (pos === 1) rank1Hits++;
    if (pos < 1 || pos > topK) {
      errors++;
      const top = ranked.slice(0, 3).map((r) => `${r.name}:${r.score.toFixed(2)}`).join(', ');
      failLines.push(`POSITIVE: "${prompt}" → ${owner} ranked ${pos || 'absent'} (need ≤${topK}); top: ${top}`);
    }
  }
  for (const neg of spec.negative || []) {
    const prompt = neg.prompt;
    const trueOwner = neg.owner;
    const ownerRank = rankOf(trueOwner, prompt, corpus);
    const siblingRank = rankOf(owner, prompt, corpus);
    if (!(ownerRank < siblingRank)) {
      errors++;
      failLines.push(`NEGATIVE: "${prompt}" → owner ${trueOwner}(${ownerRank}) must outrank ${owner}(${siblingRank})`);
    }
  }
}

// --- Description collisions ---
const collided = collisions(corpus, { errorAt: collideErrorAt, warnAt: 0.5 });
const collisionErrors = collided.filter((c) => c.level === 'error');
for (const c of collisionErrors) { errors++; failLines.push(`COLLISION: ${c.a} ~ ${c.b} = ${c.sim.toFixed(2)} (≥${collideErrorAt})`); }

// --- Rank-1 floor ---
const rank1Rate = positives ? Math.round((rank1Hits / positives) * 100) : 0;
if (rank1Rate < minRank1) { errors++; failLines.push(`RANK1: ${rank1Rate}% < floor ${minRank1}%`); }

// --- Report ---
if (!quiet) {
  const warnCollisions = collided.filter((c) => c.level === 'warn');
  if (warnCollisions.length) {
    console.log('Near-collisions (warn):');
    for (const c of warnCollisions) console.log(`  ⚠  ${c.a} ~ ${c.b} = ${c.sim.toFixed(2)}`);
    console.log('');
  }
}
for (const line of failLines) console.log(`  ✗ ${line}`);

const status = errors > 0 ? 'FAILED' : 'PASSED';
console.log(`\n${positives} positive prompts — rank-1 ${rank1Rate}% (floor ${minRank1}%) — ${errors} error(s) — ${status}`);
process.exit(errors > 0 ? 1 : 0);
