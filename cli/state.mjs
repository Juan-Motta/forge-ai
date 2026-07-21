import { basename } from 'node:path';

export function makeDefaultAnswers(cwd) {
  return {
    target: cwd,
    // Per-engine model + which engines fill each role. Reviewers answer a bare "review";
    // council advisors run in a /council. Both reference `models`.
    models: { codex: { model: 'gpt-5.6-sol', effort: 'xhigh' } },
    reviewers: ['codex'],
    council: ['codex'],
    profile: 'standard',
    withHooks: false,
    gitInit: false,
    noIsolate: false,
    project: { persona: '', info: `Project: ${basename(cwd)}`, rules: '' },
  };
}
