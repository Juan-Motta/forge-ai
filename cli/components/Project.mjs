import React from 'react';
import { Box, Text } from 'ink';
import TextInput from 'ink-text-input';
import { theme } from '../assets/anvil.ans.mjs';

const e = React.createElement;

export default function Project({ answers, setAnswers, onNext }) {
  const [rules, setRules] = React.useState(answers.project.rules);
  return e(Box, { flexDirection: 'column', paddingX: 1 },
    e(Text, { color: theme.cyan, bold: true }, 'Project'),
    e(Text, null, `Target: ${answers.target}`),
    e(Box, { marginTop: 1 },
      e(Text, null, 'Special rules (optional): '),
      e(TextInput, { value: rules, onChange: setRules,
        onSubmit: () => { setAnswers({ ...answers, project: { ...answers.project, rules } }); onNext(); } })),
    e(Text, { dimColor: true }, 'Enter to continue'));
}
