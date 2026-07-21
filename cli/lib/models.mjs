import { spawnSync } from 'node:child_process';
import { catalog } from './flags.mjs';

// Sentinel value the wizard uses to offer a free-text "type any model id" option.
export const CUSTOM = '__custom__';

function defaultSpawn(cmd, args) {
  const r = spawnSync(cmd, args, { encoding: 'utf8' });
  return { status: r.status ?? 1, stdout: r.stdout ?? '' };
}

// Cross-product of an engine's curated models × its reasoning efforts → [{model, effort}].
function curated(engine) {
  const c = catalog[engine];
  if (!c?.models) return [];
  const efforts = c.efforts?.length ? c.efforts : [null];
  return c.models.flatMap((m) => efforts.map((eff) => ({ model: m, effort: eff })));
}

// Model options for an engine, as [{ model, effort|null }].
// - OpenCode exposes a live list via `opencode models`; we use it when available.
// - Codex and Claude have no model-listing command, so we use the curated catalog
//   (each model × each reasoning level). The caller always adds a CUSTOM free-text entry.
export function optionsFor(engine, spawn = defaultSpawn) {
  if (engine === 'opencode') {
    const r = spawn('opencode', ['models']);
    if (r.status === 0 && r.stdout.trim()) {
      const models = r.stdout.split('\n').map((l) => l.trim()).filter(Boolean);
      if (models.length) return models.map((m) => ({ model: m, effort: null }));
    }
  }
  return curated(engine);
}
