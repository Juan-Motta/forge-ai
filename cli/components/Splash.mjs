import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import { art, theme } from '../assets/anvil.ans.mjs';
import { LANGS } from '../lib/i18n.mjs';
import { Item, Indicator } from './ui.mjs';

const e = React.createElement;
const OK = '#3fb950';
const NO = '#f85149';

// Splash + a compact engine summary + language picker. Choosing a language begins the wizard.
export default function Splash({ onNext, version, engines }) {
  const list = Object.values(engines ?? {});
  const enginesLine = list.length
    ? e(Box, null, ...list.flatMap((eng, i) => [
        e(Text, { key: `${eng.name}g`, color: eng.installed ? OK : NO }, eng.installed ? '✔ ' : '✗ '),
        e(Text, { key: `${eng.name}n`, color: eng.installed ? theme.text : theme.steelDim }, eng.name + (i < list.length - 1 ? '    ' : '')),
      ]))
    : null;

  return e(
    Box,
    { flexDirection: 'column', alignItems: 'center' },
    art ? e(Text, null, art) : e(Text, { color: theme.steel }, '⚒  codeforge'),
    e(Text, { color: theme.cyan, bold: true }, `codeforge ${version ?? ''}`),
    enginesLine ? e(Box, { marginTop: 1 }, enginesLine) : null,
    e(Box, { marginTop: 1 }, e(Text, { color: theme.steelDim }, 'Language · Idioma')),
    e(SelectInput, { items: LANGS, itemComponent: Item, indicatorComponent: Indicator, onSelect: (i) => onNext(i.value) }),
  );
}
