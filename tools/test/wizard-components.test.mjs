import { test } from 'node:test';
import assert from 'node:assert/strict';
import React from 'react';
import { render } from 'ink-testing-library';
import Summary from '../../cli/components/Summary.mjs';
import { makeDefaultAnswers } from '../../cli/state.mjs';

test('Summary shows the reproducible non-interactive command', () => {
  const answers = { ...makeDefaultAnswers('/tmp/x'), profile: 'light' };
  const { lastFrame } = render(React.createElement(Summary, { answers, onNext: () => {} }));
  assert.match(lastFrame(), /npx @jualopezmo\/codeforge/);
  assert.match(lastFrame(), /--profile=light/);
});
