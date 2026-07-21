import React from 'react';
import { Box, Text } from 'ink';
import SelectInput from 'ink-select-input';
import { t } from '../lib/i18n.mjs';
import { theme } from '../assets/anvil.ans.mjs';
import { Card, Item, Indicator, moveSelectFooter } from './ui.mjs';

const e = React.createElement;

// Step 1: default gate profile. Step 2 (Claude only): the opt-in hard-block hook.
export default function Gates({ answers, setAnswers, onNext, engines, lang }) {
  const { gates: g, ui } = t(lang);
  const claudeInstalled = engines?.claude?.installed;
  const [profile, setProfile] = React.useState(null);

  if (!profile) {
    const items = [
      { key: 'standard', label: g.standard, value: 'standard' },
      { key: 'light', label: g.light, value: 'light' },
    ];
    return e(Card, { title: g.title, subtitle: g.subtitle, footer: moveSelectFooter(ui) },
      e(SelectInput, {
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

  const crumb = e(Text, { color: theme.steelDim }, [g.profileCrumb, e(Text, { key: 'p', color: theme.moltenHot, bold: true }, profile)]);
  const items = [
    { key: 'no', label: g.hookNo, value: false },
    { key: 'yes', label: g.hookYes, value: true },
  ];
  return e(Card, { title: g.hookTitle, subtitle: g.hookSubtitle, crumb, footer: moveSelectFooter(ui) },
    e(SelectInput, {
      items,
      itemComponent: Item,
      indicatorComponent: Indicator,
      onSelect: (i) => { setAnswers({ ...answers, profile, withHooks: i.value }); onNext(); },
    }));
}
