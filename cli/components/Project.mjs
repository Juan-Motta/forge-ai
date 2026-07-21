import React from 'react';
import { Box, Text } from 'ink';
import TextInput from 'ink-text-input';
import { t } from '../lib/i18n.mjs';
import { theme } from '../assets/anvil.ans.mjs';
import { Card, enterFooter } from './ui.mjs';

const e = React.createElement;

export default function Project({ answers, setAnswers, onNext, lang }) {
  const { project: p, ui } = t(lang);
  const [rules, setRules] = React.useState(answers.project.rules);
  return e(Card, { title: p.title, footer: enterFooter(ui, ui.confirm) },
    e(Box, { flexDirection: 'column' },
      e(Text, { color: theme.steelDim }, [p.target, e(Text, { key: 't', color: theme.text }, answers.target)]),
      e(Box, { marginTop: 1 },
        e(Text, { color: theme.text }, p.rulesLabel),
        e(TextInput, {
          value: rules,
          onChange: setRules,
          placeholder: p.rulesPlaceholder,
          onSubmit: () => { setAnswers({ ...answers, project: { ...answers.project, rules } }); onNext(); },
        }))));
}
