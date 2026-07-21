import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import { catalog } from '../lib/flags.mjs';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

// Styled SelectInput pieces (molten pointer, cyan bold selection) shared by both phases.
const Indicator = ({ isSelected }) => e(Text, { color: theme.molten }, isSelected ? '❯ ' : '  ');
const Item = ({ isSelected, label }) =>
  e(Text, { color: isSelected ? theme.cyan : theme.text, bold: isSelected }, label);

function card({ title, subtitle, crumb, select, footer }) {
  return e(
    Box,
    { flexDirection: 'column', width: 64 },
    e(Text, { color: theme.cyan, bold: true }, title),
    e(Text, { color: theme.steelDim }, subtitle),
    e(
      Box,
      { flexDirection: 'column', marginTop: 1, borderStyle: 'round', borderColor: theme.steel, paddingX: 2, paddingY: 1 },
      crumb ? e(Box, { marginBottom: 1 }, crumb) : null,
      select,
    ),
    e(Box, { marginTop: 1 }, e(Text, { color: theme.steelDim }, [
      e(Text, { key: 'k', color: theme.molten, bold: true }, '↑↓'), ' move   ',
      e(Text, { key: 'e', color: theme.molten, bold: true }, 'Enter'), ' select',
    ])),
  );
}

const fmt = (o) => `${o.model}${o.effort ? ' · ' + o.effort : ''}`;

export default function ReviewPolicy({ answers, setAnswers, onNext }) {
  const [engine, setEngine] = React.useState(null);

  if (!engine) {
    const items = Object.keys(catalog).map((k) => ({
      key: k,
      label: `${k.padEnd(9)}  default ${fmt(catalog[k].default)}`,
      value: k,
    }));
    return card({
      title: '⚒  Default review policy',
      subtitle: 'Which engine answers a bare "review"? (you pick its model next)',
      select: e(SelectInput, { items, itemComponent: Item, indicatorComponent: Indicator, onSelect: (i) => setEngine(i.value) }),
    });
  }

  const items = catalog[engine].options.map((o) => ({ key: fmt(o), label: fmt(o), value: o }));
  const crumb = e(Text, { color: theme.steelDim }, [
    'default reviewer: ', e(Text, { key: 'e', color: theme.moltenHot, bold: true }, engine),
  ]);
  return card({
    title: `⚒  Model for ${engine}`,
    subtitle: `Used whenever ${engine} reviews (e.g. "review with ${engine}").`,
    crumb,
    select: e(SelectInput, {
      items,
      itemComponent: Item,
      indicatorComponent: Indicator,
      onSelect: (i) => {
        setAnswers({ ...answers, defaultReviewer: engine, reviewers: [{ engine, model: i.value.model, effort: i.value.effort }] });
        onNext();
      },
    }),
  });
}
