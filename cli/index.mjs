import React from 'react';
import { render, Box } from 'ink';
import { makeDefaultAnswers } from './state.mjs';
import Splash from './components/Splash.mjs';
import Detect from './components/Detect.mjs';
import ReviewPolicy from './components/ReviewPolicy.mjs';
import Gates from './components/Gates.mjs';
import Project from './components/Project.mjs';
import Summary from './components/Summary.mjs';

const e = React.createElement;
const STEPS = ['splash', 'detect', 'review', 'gates', 'project', 'summary'];

function Wizard({ pkgRoot, version, resolve }) {
  const [answers, setAnswers] = React.useState(makeDefaultAnswers(process.cwd()));
  const [engines, setEngines] = React.useState(null);
  const [i, setI] = React.useState(0);
  const next = () => setI((n) => Math.min(n + 1, STEPS.length - 1));
  const step = STEPS[i];
  let screen;
  if (step === 'splash') screen = e(Splash, { onNext: next, version });
  else if (step === 'detect') screen = e(Detect, { onNext: (eng) => { setEngines(eng); next(); } });
  else if (step === 'review') screen = e(ReviewPolicy, { answers, setAnswers, onNext: next });
  else if (step === 'gates') screen = e(Gates, { answers, setAnswers, engines, onNext: next });
  else if (step === 'project') screen = e(Project, { answers, setAnswers, onNext: next });
  else screen = e(Summary, { answers, onNext: (ok) => resolve(ok ? answers : null) });
  return e(Box, { flexDirection: 'column' }, screen);
}

export function runWizard(pkgRoot, version) {
  return new Promise((resolve) => {
    const { unmount } = render(e(Wizard, { pkgRoot, version, resolve: (a) => { unmount(); resolve(a); } }));
  });
}
