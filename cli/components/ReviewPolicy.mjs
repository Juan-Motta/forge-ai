import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import { catalog } from '../lib/flags.mjs';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

// Pick the default reviewer engine, then its model. Non-driver engines only would be
// ideal, but the driver isn't known at install time, so we offer all catalog engines.
export default function ReviewPolicy({ answers, setAnswers, onNext }) {
  const [engine, setEngine] = React.useState(null);
  if (!engine) {
    const items = Object.keys(catalog).map((k) => ({ label: `Review by default with: ${k}`, value: k }));
    return e(Box, { flexDirection: 'column', paddingX: 1 },
      e(Text, { color: theme.cyan, bold: true }, 'Default review policy'),
      e(Text, { dimColor: true }, 'Which engine answers a bare "review"? (model next)'),
      e(SelectInput, { items, onSelect: (i) => setEngine(i.value) }));
  }
  const items = catalog[engine].options.map((o) => ({
    key: `${o.model}${o.effort ? ':' + o.effort : ''}`,
    label: `${o.model}${o.effort ? ' · ' + o.effort : ''}`,
    value: o,
  }));
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, `Model for ${engine}`),
    e(SelectInput, { items, onSelect: (i) => {
      setAnswers({ ...answers, defaultReviewer: engine,
        reviewers: [{ engine, model: i.value.model, effort: i.value.effort }] });
      onNext();
    } }));
}
