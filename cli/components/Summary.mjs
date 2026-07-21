import React from 'react';
import { Box, Text, useInput } from 'ink';
import { nonInteractiveCommand } from '../lib/flags.mjs';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Summary({ answers, onNext }) {
  useInput((input, key) => { if (key.return) onNext(true); if (input === 'q') onNext(false); });
  const cmd = nonInteractiveCommand(answers);
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, 'Review & confirm'),
    e(Text, null, `Target: ${answers.target}`),
    e(Text, null, `Profile: ${answers.profile}   Hooks: ${answers.withHooks ? 'yes' : 'no'}`),
    e(Text, null, `Default reviewer: ${answers.defaultReviewer ?? '(none)'}`),
    e(Box, { marginTop: 1, flexDirection: 'column' },
      e(Text, { color: theme.molten },
        'Equivalent non-interactive install (defaults — review policy is wizard-only for now):'),
      e(Text, { wrap: 'wrap' }, cmd)),
    e(Box, { marginTop: 1 }, e(Text, { dimColor: true }, 'Enter = install   q = cancel')));
}
