import React from 'react';
import SelectInput from 'ink-select-input';
import { optionsFor } from '../lib/models.mjs';
import { t } from '../lib/i18n.mjs';
import { Card, Item, Indicator, moveSelectFooter } from './ui.mjs';

const e = React.createElement;
const fmt = (o) => `${o.model}${o.effort ? ' · ' + o.effort : ''}`;

// Claude-only step: choose inline vs subagent-driven execution, and (if subagent-driven)
// the model dispatched implementation subagents run with. Only shown when Claude is installed.
export default function ClaudeAgents({ answers, setAnswers, onNext, lang }) {
  const { claude: c, ui } = t(lang);
  const [mode, setMode] = React.useState(null);

  if (!mode) {
    const items = [
      { key: 'inline', label: c.inline, value: 'inline' },
      { key: 'subagent', label: c.subagent, value: 'subagent' },
    ];
    return e(Card, { title: c.title, subtitle: c.subtitle, footer: moveSelectFooter(ui) },
      e(SelectInput, {
        items,
        itemComponent: Item,
        indicatorComponent: Indicator,
        onSelect: (i) => {
          if (i.value === 'inline') { setAnswers({ ...answers, claude: { subagents: false, model: null } }); onNext(); return; }
          setMode('subagent');
        },
      }));
  }

  const items = optionsFor('claude').map((o) => ({ key: fmt(o), label: fmt(o), value: o }));
  return e(Card, { title: c.modelTitle, subtitle: c.modelSubtitle, footer: moveSelectFooter(ui) },
    e(SelectInput, {
      items,
      limit: 8,
      itemComponent: Item,
      indicatorComponent: Indicator,
      onSelect: (i) => { setAnswers({ ...answers, claude: { subagents: true, model: i.value } }); onNext(); },
    }));
}
