import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import TextInput from 'ink-text-input';
import { catalog } from '../lib/flags.mjs';
import { optionsFor, CUSTOM } from '../lib/models.mjs';
import { t } from '../lib/i18n.mjs';
import { theme } from '../assets/anvil.ans.mjs';
import { Card, Item, Indicator, moveSelectFooter, enterFooter } from './ui.mjs';

const e = React.createElement;
const fmt = (o) => `${o.model}${o.effort ? ' · ' + o.effort : ''}`;

export default function ReviewPolicy({ answers, setAnswers, onNext, lang }) {
  const { review: r, ui } = t(lang);
  const [engine, setEngine] = React.useState(null);
  const [custom, setCustom] = React.useState(false);
  const [text, setText] = React.useState('');

  // Phase 1 — pick the default reviewer engine.
  if (!engine) {
    const items = Object.keys(catalog).map((k) => ({
      key: k,
      label: r.engineDefault(k, fmt(catalog[k].default)),
      value: k,
    }));
    return e(Card, { title: r.title, subtitle: r.subtitle, footer: moveSelectFooter(ui) },
      e(SelectInput, { items, itemComponent: Item, indicatorComponent: Indicator, onSelect: (i) => setEngine(i.value) }));
  }

  const crumb = e(Text, { color: theme.steelDim }, [r.crumb, e(Text, { key: 'e', color: theme.moltenHot, bold: true }, engine)]);

  // Phase 3 — free-text custom model id.
  if (custom) {
    return e(Card, { title: r.customTitle(engine), subtitle: r.customSubtitle, crumb, footer: enterFooter(ui, ui.confirm) },
      e(Box, null,
        e(Text, { color: theme.text }, r.modelField),
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
        })));
  }

  // Phase 2 — pick a model (live for opencode, curated for codex/claude) or go custom.
  const items = [
    ...optionsFor(engine).map((o) => ({ key: fmt(o), label: fmt(o), value: o })),
    { key: CUSTOM, label: r.customOption, value: CUSTOM },
  ];
  return e(Card, { title: r.modelTitle(engine), subtitle: r.modelSubtitle(engine), crumb, footer: moveSelectFooter(ui) },
    e(SelectInput, {
      items,
      limit: 8,
      itemComponent: Item,
      indicatorComponent: Indicator,
      onSelect: (i) => {
        if (i.value === CUSTOM) { setCustom(true); return; }
        setAnswers({ ...answers, defaultReviewer: engine, reviewers: [{ engine, model: i.value.model, effort: i.value.effort }] });
        onNext();
      },
    }));
}
