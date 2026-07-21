import { basename } from 'node:path';

export function makeDefaultAnswers(cwd) {
  return {
    target: cwd,
    reviewers: [{ engine: 'codex', model: 'gpt-5.6-sol', effort: 'xhigh' }],
    defaultReviewer: 'codex',
    profile: 'standard',
    withHooks: false,
    gitInit: false,
    noIsolate: false,
    project: { persona: '', info: `Project: ${basename(cwd)}`, rules: '' },
  };
}
