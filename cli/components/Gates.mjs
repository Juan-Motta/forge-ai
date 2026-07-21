import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import { theme } from '../assets/anvil.ans.mjs';
import { Card, Item, Indicator, moveSelectFooter } from './ui.mjs';

const e = React.createElement;

// Two steps: pick the default gate profile, then (Claude only) whether to install the
// opt-in hard-block hook. Ship-gates are a checklist in .workflow/state.md that must be
// complete before push/PR; the profile sets how many gates are required.
export default function Gates({ answers, setAnswers, onNext, engines }) {
  const claudeInstalled = engines?.claude?.installed;
  const [profile, setProfile] = React.useState(null);

  // Step 1 — default gate profile.
  if (!profile) {
    const items = [
      { key: 'standard', label: 'standard   6 gates · full features & bug fixes', value: 'standard' },
      { key: 'light', label: 'light      3 gates · quick-fix / trivial changes', value: 'light' },
    ];
    return e(Card, {
      title: '⚒  Ship-gates',
      subtitle: 'A checklist in .workflow/state.md must be complete before git push / PR. Profile sets how many gates are required (a default — each workflow can override).',
      footer: moveSelectFooter,
    }, e(SelectInput, {
      items,
      itemComponent: Item,
      indicatorComponent: Indicator,
      onSelect: (i) => {
        if (claudeInstalled) { setProfile(i.value); return; }
        setAnswers({ ...answers, profile: i.value });
        onNext();
      },
    }));
  }

  // Step 2 — optional Claude hard-block hook.
  const crumb = e(Text, { color: theme.steelDim }, ['profile: ', e(Text, { key: 'p', color: theme.moltenHot, bold: true }, profile)]);
  const items = [
    { key: 'no', label: 'No — advisory + native approval prompt (default)', value: false },
    { key: 'yes', label: 'Yes — hard-block push/PR when gates are incomplete', value: true },
  ];
  return e(Card, {
    title: '⚒  Hard-block hook (Claude only)',
    subtitle: 'Optional: a Claude Code PreToolUse hook that actually blocks a ship action when the gates are not green. Without it, gates are advisory + a native approval prompt.',
    crumb,
    footer: moveSelectFooter,
  }, e(SelectInput, {
    items,
    itemComponent: Item,
    indicatorComponent: Indicator,
    onSelect: (i) => {
      setAnswers({ ...answers, profile, withHooks: i.value });
      onNext();
    },
  }));
}
