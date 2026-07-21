import React from 'react';
import { Box, Text, useInput } from 'ink';
import { art, theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Splash({ onNext, version }) {
  useInput((input, key) => { if (key.return || input === ' ') onNext(); });
  return e(Box, { flexDirection: 'column', alignItems: 'center', paddingY: 1 },
    art ? e(Text, null, art) : e(Text, { color: theme.steel }, '⚒  codeforge'),
    e(Text, { color: theme.cyan, bold: true }, `codeforge ${version ?? ''}`),
    e(Text, { dimColor: true }, 'cross-engine workflow discipline — press Enter to begin'));
}
