import React from 'react';
import { Box, Text } from 'ink';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

// Shared wizard chrome so every screen looks the same.
export const Indicator = ({ isSelected }) => e(Text, { color: theme.molten }, isSelected ? '❯ ' : '  ');

export const Item = ({ isSelected, label }) =>
  e(Text, { color: isSelected ? theme.cyan : theme.text, bold: isSelected }, label);

export const moveSelectFooter = [
  e(Text, { key: 'm', color: theme.molten, bold: true }, '↑↓'), ' move   ',
  e(Text, { key: 's', color: theme.molten, bold: true }, 'Enter'), ' select',
];

export const enterFooter = (word) => [
  e(Text, { key: 's', color: theme.molten, bold: true }, 'Enter'), ` ${word}`,
];

// Bordered card: cyan title, dim subtitle, optional breadcrumb, framed body, footer.
export function Card({ title, subtitle, crumb, footer, children, width = 64 }) {
  return e(
    Box,
    { flexDirection: 'column', width },
    e(Text, { color: theme.cyan, bold: true }, title),
    subtitle ? e(Text, { color: theme.steelDim }, subtitle) : null,
    e(
      Box,
      { flexDirection: 'column', marginTop: 1, borderStyle: 'round', borderColor: theme.steel, paddingX: 2, paddingY: 1 },
      crumb ? e(Box, { marginBottom: 1 }, crumb) : null,
      children,
    ),
    footer ? e(Box, { marginTop: 1 }, e(Text, { color: theme.steelDim }, footer)) : null,
  );
}
