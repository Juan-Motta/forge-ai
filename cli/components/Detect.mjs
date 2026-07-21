import React from 'react';
import { Box, Text, useInput } from 'ink';
import { detectAll } from '../lib/detect.mjs';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;
const OK = '#3fb950';
const NO = '#f85149';

function Row({ eng }) {
  const glyph = eng.installed ? '✔' : '✗';
  const right = eng.installed ? (eng.version ?? 'installed') : 'not installed';
  const note = eng.installed ? 'usable as reviewer' : eng.hint.replace(/^install \w+: /, '↳ ');
  return e(
    Box,
    { key: eng.name },
    e(Text, { color: eng.installed ? OK : NO }, `${glyph} `),
    e(Text, { color: theme.text, bold: true }, eng.name.padEnd(11)),
    e(Text, { color: eng.installed ? theme.steel : NO }, right.padEnd(15)),
    e(Text, { color: theme.steelDim }, note),
  );
}

export default function Detect({ onNext }) {
  const engines = React.useMemo(() => detectAll(), []);
  useInput((input, key) => { if (key.return) onNext(engines); });
  const list = Object.values(engines);
  const count = list.filter((x) => x.installed).length;

  return e(
    Box,
    { flexDirection: 'column', width: 66 },
    e(Text, { color: theme.cyan, bold: true }, '⚒  Engines detected'),
    e(Text, { color: theme.steelDim }, "You don't need all three — this just informs your review setup."),
    e(
      Box,
      { flexDirection: 'column', marginTop: 1, borderStyle: 'round', borderColor: theme.steel, paddingX: 2, paddingY: 1 },
      ...list.map((eng) => e(Row, { key: eng.name, eng })),
    ),
    e(
      Box,
      { marginTop: 1, justifyContent: 'space-between' },
      e(Text, { color: theme.steelDim }, `${count}/3 available`),
      e(Text, { color: theme.steelDim }, [e(Text, { key: 'k', color: theme.molten, bold: true }, 'Enter'), ' to continue']),
    ),
  );
}
