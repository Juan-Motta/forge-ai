import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Gates({ answers, setAnswers, onNext, engines }) {
  const claudeInstalled = engines?.claude?.installed;
  const items = [
    { label: 'Profile: standard (full gates)', value: { profile: 'standard' } },
    { label: 'Profile: light (quick-fix)', value: { profile: 'light' } },
  ];
  if (claudeInstalled) {
    items.push({ label: 'Also install the Claude hard-block hook (--with-hooks)', value: { withHooks: true } });
  }
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, 'Gates'),
    e(SelectInput, { items, onSelect: (i) => { setAnswers({ ...answers, ...i.value }); onNext(); } }));
}
