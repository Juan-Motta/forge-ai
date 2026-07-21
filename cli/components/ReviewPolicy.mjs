import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import TextInput from 'ink-text-input';
import { catalog } from '../lib/flags.mjs';
import { optionsFor, CUSTOM } from '../lib/models.mjs';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

const Indicator = ({ isSelected }) => e(Text, { color: theme.molten }, isSelected ? '❯ ' : '  ');
const Item = ({ isSelected, label }) =>
  e(Text, { color: isSelected ? theme.cyan : theme.text, bold: isSelected }, label);

function card({ title, subtitle, crumb, body, footer }) {
  return e(
    Box,
    { flexDirection: 'column', width: 64 },
    e(Text, { color: theme.cyan, bold: true }, title),
    e(Text, { color: theme.steelDim }, subtitle),
    e(
      Box,
      { flexDirection: 'column', marginTop: 1, borderStyle: 'round', borderColor: theme.steel, paddingX: 2, paddingY: 1 },
      crumb ? e(Box, { marginBottom: 1 }, crumb) : null,
      body,
    ),
    e(Box, { marginTop: 1 }, e(Text, { color: theme.steelDim }, footer)),
  );
}

const fmt = (o) => `${o.model}${o.effort ? ' · ' + o.effort : ''}`;
const moveSelectFooter = [
  e(Text, { key: 'm', color: theme.molten, bold: true }, '↑↓'), ' move   ',
  e(Text, { key: 's', color: theme.molten, bold: true }, 'Enter'), ' select',
];

export default function ReviewPolicy({ answers, setAnswers, onNext }) {
  const [engine, setEngine] = React.useState(null);
  const [custom, setCustom] = React.useState(false);
  const [text, setText] = React.useState('');

  // Phase 1 — pick the default reviewer engine.
  if (!engine) {
    const items = Object.keys(catalog).map((k) => ({
      key: k,
      label: `${k.padEnd(9)}  default ${fmt(catalog[k].default)}`,
      value: k,
    }));
    return card({
      title: '⚒  Default review policy',
      subtitle: 'Which engine answers a bare "review"? (you pick its model next)',
      body: e(SelectInput, { items, itemComponent: Item, indicatorComponent: Indicator, onSelect: (i) => setEngine(i.value) }),
      footer: moveSelectFooter,
    });
  }

  const crumb = e(Text, { color: theme.steelDim }, [
    'default reviewer: ', e(Text, { key: 'e', color: theme.moltenHot, bold: true }, engine),
  ]);

  // Phase 3 — free-text custom model id.
  if (custom) {
    return card({
      title: `⚒  Custom model for ${engine}`,
      subtitle: 'Type any model id this engine accepts, then press Enter.',
      crumb,
      body: e(Box, null,
        e(Text, { color: theme.text }, 'model: '),
        e(TextInput, {
          value: text,
          onChange: setText,
          placeholder: catalog[engine]?.default?.model ?? 'model-id',
          onSubmit: () => {
            const model = text.trim() || catalog[engine]?.default?.model;
            if (!model) return;
            setAnswers({ ...answers, defaultReviewer: engine, reviewers: [{ engine, model, effort: null }] });
            onNext();
          },
        })),
      footer: [e(Text, { key: 's', color: theme.molten, bold: true }, 'Enter'), ' confirm'],
    });
  }

  // Phase 2 — pick a model (live list for opencode, curated for codex/claude) or go custom.
  const opts = optionsFor(engine);
  const items = [
    ...opts.map((o) => ({ key: fmt(o), label: fmt(o), value: o })),
    { key: CUSTOM, label: '✎  custom model id…', value: CUSTOM },
  ];
  return card({
    title: `⚒  Model for ${engine}`,
    subtitle: `Used whenever ${engine} reviews (e.g. "review with ${engine}").`,
    crumb,
    body: e(SelectInput, {
      items,
      limit: 8,
      itemComponent: Item,
      indicatorComponent: Indicator,
      onSelect: (i) => {
        if (i.value === CUSTOM) { setCustom(true); return; }
        setAnswers({ ...answers, defaultReviewer: engine, reviewers: [{ engine, model: i.value.model, effort: i.value.effort }] });
        onNext();
      },
    }),
    footer: moveSelectFooter,
  });
}
