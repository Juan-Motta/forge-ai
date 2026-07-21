// routing — deterministic, dependency-free approximation of skill routing.
//
// Skills are discovered by their `description`. Two failure modes dominate real
// trigger bugs: (a) a description missing the vocabulary users actually say
// (false negative), and (b) two descriptions so similar neither routes
// reliably (false positive / collision). This module ranks skills for a prompt
// by stemmed TF-IDF cosine similarity and detects near-collisions — a lexical
// approximation (not semantics; that's a behavioral eval's job), but it catches
// exactly those two classes cheaply and reproducibly.

// Stopwords: standard English + this catalog's shared boilerplate. Every
// codeforge description ends "...under Claude Code, Codex, or OpenCode" and opens
// with "Use when/for" — left in, that boilerplate dominates similarity and
// manufactures false collisions. Engine names are catalog-wide noise here.
const STOPWORDS = new Set([
  'a', 'an', 'the', 'and', 'or', 'of', 'to', 'in', 'on', 'for', 'with', 'at', 'by', 'from',
  'is', 'are', 'be', 'been', 'it', 'this', 'that', 'these', 'those', 'as', 'so', 'then',
  'you', 'your', 'i', 'we', 'they', 'them', 'their', 'my', 'me', 'us', 'any', 'each', 'per',
  'do', 'does', 'done', 'need', 'want', 'get', 'got', 'make', 'run', 'via', 'into', 'out',
  'when', 'where', 'what', 'which', 'who', 'how', 'why', 'before', 'after', 'under', 'over',
  'use', 'used', 'using', 'not', 'no', 'yes', 'if', 'but', 'up', 'down', 'off', 'about',
  // engine names — catalog-wide boilerplate, never a routing signal
  'claude', 'code', 'codex', 'opencode', 'harness', 'harnesses', 'engine', 'engines',
]);

/** Lowercase, split on non-alphanumerics, drop stopwords, light suffix-stem. */
export function tokenize(text) {
  const out = [];
  for (const raw of String(text).toLowerCase().split(/[^a-z0-9]+/)) {
    if (!raw || raw.length < 3) continue;
    if (STOPWORDS.has(raw)) continue;
    out.push(stem(raw));
  }
  return out;
}

/** Deliberately conservative stemmer — collapse common inflections only. */
function stem(w) {
  if (w.length > 5 && w.endsWith('ing')) w = undouble(w.slice(0, -3));
  else if (w.length > 5 && w.endsWith('ies')) w = w.slice(0, -3) + 'y';
  else if (w.length > 4 && w.endsWith('es')) w = w.slice(0, -2);
  else if (w.length > 4 && w.endsWith('ed')) w = undouble(w.slice(0, -2));
  else if (w.length > 4 && w.endsWith('s') && !w.endsWith('ss')) w = w.slice(0, -1);
  if (w.length > 5 && w.endsWith('ly')) w = w.slice(0, -2);
  return w;
}

// Collapse a doubled final consonant left by -ing/-ed removal so "shipping"→
// "ship" (not "shipp") aligns with "ship". Keep ss/ll/zz (pass, call, buzz).
function undouble(w) {
  const n = w.length;
  if (n >= 3 && w[n - 1] === w[n - 2] && !'slz'.includes(w[n - 1]) && /[bcdfghjkmnpqrtv]/.test(w[n - 1])) {
    return w.slice(0, -1);
  }
  return w;
}

/**
 * Build an IDF map + per-document TF-IDF vectors from labeled documents.
 * @param {Array<{name:string, text:string}>} docs
 */
export function buildCorpus(docs) {
  const df = new Map();
  const tokensByDoc = new Map();
  for (const { name, text } of docs) {
    const toks = tokenize(text);
    tokensByDoc.set(name, toks);
    for (const t of new Set(toks)) df.set(t, (df.get(t) || 0) + 1);
  }
  const N = docs.length;
  const idf = new Map();
  for (const [t, d] of df) idf.set(t, Math.log((N + 1) / (d + 1)) + 1); // smoothed
  const vectors = new Map();
  for (const [name, toks] of tokensByDoc) vectors.set(name, vectorize(toks, idf));
  return { idf, vectors };
}

/** Turn tokens into an L2-normalized TF-IDF vector (sublinear TF). */
export function vectorize(tokens, idf) {
  const tf = new Map();
  for (const t of tokens) tf.set(t, (tf.get(t) || 0) + 1);
  const vec = new Map();
  let norm = 0;
  for (const [t, c] of tf) {
    const w = (1 + Math.log(c)) * (idf.get(t) || 0);
    if (w > 0) { vec.set(t, w); norm += w * w; }
  }
  norm = Math.sqrt(norm) || 1;
  for (const [t, w] of vec) vec.set(t, w / norm);
  return vec;
}

export function cosine(a, b) {
  let dot = 0;
  const [small, big] = a.size < b.size ? [a, b] : [b, a];
  for (const [t, w] of small) if (big.has(t)) dot += w * big.get(t);
  return dot; // vectors are already L2-normalized
}

/** Rank all skills for a query prompt, highest similarity first. */
export function rankSkills(prompt, corpus) {
  const qv = vectorize(tokenize(prompt), corpus.idf);
  const scored = [];
  for (const [name, vec] of corpus.vectors) scored.push({ name, score: cosine(qv, vec) });
  scored.sort((x, y) => y.score - x.score || x.name.localeCompare(y.name));
  return scored;
}

/** Rank position (1-based) of `name` for a prompt; Infinity if absent. */
export function rankOf(name, prompt, corpus) {
  const ranked = rankSkills(prompt, corpus);
  const i = ranked.findIndex((r) => r.name === name);
  return i < 0 ? Infinity : i + 1;
}

/**
 * Pairwise description near-collisions.
 * @returns {Array<{a,b,sim,level}>} level 'error' (>=errorAt) or 'warn' (>=warnAt)
 */
export function collisions(corpus, { errorAt = 0.75, warnAt = 0.5 } = {}) {
  const names = [...corpus.vectors.keys()];
  const hits = [];
  for (let i = 0; i < names.length; i++) {
    for (let j = i + 1; j < names.length; j++) {
      const sim = cosine(corpus.vectors.get(names[i]), corpus.vectors.get(names[j]));
      if (sim >= errorAt) hits.push({ a: names[i], b: names[j], sim, level: 'error' });
      else if (sim >= warnAt) hits.push({ a: names[i], b: names[j], sim, level: 'warn' });
    }
  }
  return hits.sort((x, y) => y.sim - x.sim);
}
