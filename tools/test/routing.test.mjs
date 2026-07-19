// Tests for tools/lib/routing.mjs — run with `node --test tools/test/`.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tokenize, buildCorpus, rankSkills, rankOf, collisions, vectorize, cosine } from '../lib/routing.mjs';

test('tokenize drops stopwords and engine names', () => {
  const toks = tokenize('Use when shipping under Claude Code, Codex, or OpenCode');
  assert.ok(!toks.includes('use'));
  assert.ok(!toks.includes('claude'));
  assert.ok(!toks.includes('codex'));
  assert.ok(!toks.includes('opencode'));
});

test('stemmer collapses doubled consonant: shipping -> ship', () => {
  assert.deepEqual(tokenize('shipping'), tokenize('ship'));
  assert.deepEqual(tokenize('planning'), tokenize('plan'));
});

test('stemmer keeps ss/ll (pass, call)', () => {
  assert.ok(tokenize('passing').includes('pass'));
});

test('identical vectors have cosine 1', () => {
  const { idf } = buildCorpus([{ name: 'x', text: 'alpha beta gamma' }]);
  const v = vectorize(tokenize('alpha beta gamma'), idf);
  assert.ok(Math.abs(cosine(v, v) - 1) < 1e-9);
});

test('rankSkills routes a query to the lexically-closest skill', () => {
  const corpus = buildCorpus([
    { name: 'bugfix', text: 'reproduce a defect with a failing test and fix the root cause' },
    { name: 'planner', text: 'compare design approaches and choose one with rationale' },
  ]);
  assert.equal(rankSkills('reproduce the defect and fix it', corpus)[0].name, 'bugfix');
  assert.equal(rankSkills('compare approaches and pick a design', corpus)[0].name, 'planner');
});

test('rankOf returns 1-based position, Infinity when absent', () => {
  const corpus = buildCorpus([{ name: 'a', text: 'alpha' }, { name: 'b', text: 'beta' }]);
  assert.equal(rankOf('a', 'alpha', corpus), 1);
  assert.equal(rankOf('zzz', 'alpha', corpus), Infinity);
});

test('near-identical descriptions collide at the error threshold', () => {
  const corpus = buildCorpus([
    { name: 'one', text: 'reproduce a defect fix the root cause verify' },
    { name: 'two', text: 'reproduce a defect fix the root cause verify' },
  ]);
  const hits = collisions(corpus, { errorAt: 0.75, warnAt: 0.5 });
  assert.ok(hits.some((h) => h.level === 'error'));
});

test('distinct descriptions do not collide', () => {
  const corpus = buildCorpus([
    { name: 'one', text: 'reproduce a defect and fix the root cause' },
    { name: 'two', text: 'generate a high level project orientation map' },
  ]);
  assert.equal(collisions(corpus, { errorAt: 0.75, warnAt: 0.5 }).length, 0);
});
