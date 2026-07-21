// Wizard copy in English + Spanish. t(lang) returns the whole string tree for that
// language (falling back to English). Parameterized strings are functions.
const en = {
  splash: {
    tagline: 'cross-engine workflow discipline',
    detected: 'detected',
    langPrompt: 'Language · Idioma',
  },
  review: {
    title: '⚒  Default review policy',
    subtitle: 'Which engine answers a bare "review"? (you pick its model next)',
    engineDefault: (k, model) => `${k.padEnd(9)}  default ${model}`,
    modelTitle: (eng) => `⚒  Model for ${eng}`,
    modelSubtitle: (eng) => `Used whenever ${eng} reviews (e.g. "review with ${eng}").`,
    crumb: 'default reviewer: ',
    customOption: '✎  custom model id…',
    customTitle: (eng) => `⚒  Custom model for ${eng}`,
    customSubtitle: 'Type any model id this engine accepts, then press Enter.',
    modelField: 'model: ',
  },
  gates: {
    title: '⚒  Ship-gates',
    subtitle: 'A checklist in .workflow/state.md must be complete before git push / PR. Profile sets how many gates are required (a default — each workflow can override).',
    standard: 'standard   6 gates · full features & bug fixes',
    light: 'light      3 gates · quick-fix / trivial changes',
    hookTitle: '⚒  Hard-block hook (Claude only)',
    hookSubtitle: 'Optional: a Claude Code PreToolUse hook that actually blocks a ship action when the gates are not green. Without it, gates are advisory + a native approval prompt.',
    profileCrumb: 'profile: ',
    hookNo: 'No — advisory + native approval prompt (default)',
    hookYes: 'Yes — hard-block push/PR when gates are incomplete',
  },
  project: {
    title: '⚒  Project',
    target: 'Target: ',
    rulesLabel: 'Special rules (optional): ',
    rulesPlaceholder: 'e.g. never touch prod',
  },
  summary: {
    title: '⚒  Review & confirm',
    target: 'Target: ',
    profileHooks: (p, h) => `Profile: ${p}   Hooks: ${h ? 'yes' : 'no'}`,
    reviewer: (r) => `Default reviewer: ${r ?? '(none)'}`,
    repro: 'Equivalent non-interactive install (defaults — review policy is wizard-only for now):',
  },
  ui: { move: 'move', select: 'select', enter: 'Enter', confirm: 'confirm', install: 'install', cancel: 'cancel', begin: 'begin' },
};

const es = {
  splash: {
    tagline: 'disciplina de workflow cross-engine',
    detected: 'detectados',
    langPrompt: 'Idioma · Language',
  },
  review: {
    title: '⚒  Política de review por defecto',
    subtitle: '¿Qué engine responde a un "revisa" a secas? (el modelo se elige después)',
    engineDefault: (k, model) => `${k.padEnd(9)}  por defecto ${model}`,
    modelTitle: (eng) => `⚒  Modelo para ${eng}`,
    modelSubtitle: (eng) => `Se usa cuando ${eng} revisa (ej. "revisa con ${eng}").`,
    crumb: 'reviewer por defecto: ',
    customOption: '✎  id de modelo personalizado…',
    customTitle: (eng) => `⚒  Modelo personalizado para ${eng}`,
    customSubtitle: 'Escribe cualquier id de modelo que acepte este engine y presiona Enter.',
    modelField: 'modelo: ',
  },
  gates: {
    title: '⚒  Ship-gates',
    subtitle: 'Un checklist en .workflow/state.md debe estar completo antes de git push / PR. El perfil define cuántos gates se exigen (un valor por defecto — cada workflow puede cambiarlo).',
    standard: 'standard   6 gates · features y bugfixes completos',
    light: 'light      3 gates · quick-fix / cambios triviales',
    hookTitle: '⚒  Hook de bloqueo duro (solo Claude)',
    hookSubtitle: 'Opcional: un hook PreToolUse de Claude Code que bloquea de verdad el push/PR cuando los gates no están verdes. Sin él, los gates son advisory + el prompt de aprobación nativo.',
    profileCrumb: 'perfil: ',
    hookNo: 'No — advisory + prompt de aprobación nativo (por defecto)',
    hookYes: 'Sí — bloquear push/PR cuando los gates estén incompletos',
  },
  project: {
    title: '⚒  Proyecto',
    target: 'Destino: ',
    rulesLabel: 'Reglas especiales (opcional): ',
    rulesPlaceholder: 'ej. nunca tocar prod',
  },
  summary: {
    title: '⚒  Revisar y confirmar',
    target: 'Destino: ',
    profileHooks: (p, h) => `Perfil: ${p}   Hooks: ${h ? 'sí' : 'no'}`,
    reviewer: (r) => `Reviewer por defecto: ${r ?? '(ninguno)'}`,
    repro: 'Instalación no-interactiva equivalente (defaults — la política de review es solo del wizard por ahora):',
  },
  ui: { move: 'mover', select: 'elegir', enter: 'Enter', confirm: 'confirmar', install: 'instalar', cancel: 'cancelar', begin: 'empezar' },
};

const dict = { en, es };
export const LANGS = [
  { key: 'en', label: 'English', value: 'en' },
  { key: 'es', label: 'Español', value: 'es' },
];
export const t = (lang) => dict[lang] ?? en;
