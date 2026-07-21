import React from 'react';
import { Box, Text, useInput } from 'ink';
import { detectAll } from '../lib/detect.mjs';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Detect({ onNext }) {
  const engines = React.useMemo(() => detectAll(), []);
  useInput((input, key) => { if (key.return) onNext(engines); });
  const rows = Object.values(engines).map((eng) =>
    e(Text, { key: eng.name, color: eng.installed ? theme.steel : undefined, dimColor: !eng.installed },
      `${eng.installed ? '✓' : '✗'} ${eng.name.padEnd(9)} ${eng.installed ? eng.version ?? 'installed' : eng.hint}`));
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, 'Engines detected'),
    e(Text, { dimColor: true }, 'You do NOT need all three — this just informs your review setup.'),
    e(Box, { flexDirection: 'column', marginTop: 1 }, ...rows),
    e(Box, { marginTop: 1 }, e(Text, { dimColor: true }, 'Enter = continue')));
}
