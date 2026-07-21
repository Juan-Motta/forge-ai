import React from 'react';
import { Box, Text, useInput } from 'ink';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

// Checkbox list: ↑↓ move, space toggles, Enter confirms (needs ≥ minSelect).
export function MultiSelect({ items, initial = [], minSelect = 0, onConfirm }) {
  const [cursor, setCursor] = React.useState(0);
  const [sel, setSel] = React.useState(() => new Set(initial));
  useInput((input, key) => {
    if (key.upArrow) setCursor((c) => (c - 1 + items.length) % items.length);
    else if (key.downArrow) setCursor((c) => (c + 1) % items.length);
    else if (input === ' ') {
      const v = items[cursor].value;
      const n = new Set(sel);
      n.has(v) ? n.delete(v) : n.add(v);
      setSel(n);
    } else if (key.return && sel.size >= minSelect) {
      onConfirm(items.filter((it) => sel.has(it.value)).map((it) => it.value));
    }
  });
  return e(Box, { flexDirection: 'column' }, ...items.map((it, idx) => {
    const on = sel.has(it.value);
    const cur = idx === cursor;
    return e(Text, { key: it.key, color: cur ? theme.cyan : on ? theme.text : theme.steelDim, bold: cur },
      `${cur ? '❯' : ' '} ${on ? '◉' : '○'} ${it.label}`);
  }));
}

// Shared wizard chrome so every screen looks the same.
export const Indicator = ({ isSelected }) => e(Text, { color: theme.molten }, isSelected ? '❯ ' : '  ');

export const Item = ({ isSelected, label }) =>
  e(Text, { color: isSelected ? theme.cyan : theme.text, bold: isSelected }, label);

export const moveSelectFooter = (ui) => [
  e(Text, { key: 'm', color: theme.molten, bold: true }, '↑↓'), ` ${ui.move}   `,
  e(Text, { key: 's', color: theme.molten, bold: true }, ui.enter), ` ${ui.select}`,
];

export const enterFooter = (ui, word) => [
  e(Text, { key: 's', color: theme.molten, bold: true }, ui.enter), ` ${word}`,
];

export const multiFooter = (ui) => [
  e(Text, { key: 'm', color: theme.molten, bold: true }, '↑↓'), ` ${ui.move}   `,
  e(Text, { key: 't', color: theme.molten, bold: true }, ui.space), ` ${ui.toggle}   `,
  e(Text, { key: 's', color: theme.molten, bold: true }, ui.enter), ` ${ui.confirm}`,
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
