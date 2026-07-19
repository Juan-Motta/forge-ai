# Análisis — Claude Opus 4.8

## Tesis central

forge-ai tiene una **identidad clara y valiosa** (portabilidad cross-engine real, thin install,
skills+config sin hooks) pero está en un punto donde su mayor riesgo NO es faltarle features —
es **no tener forma de saber si sus skills realmente funcionan**. El repo B (agent-skills) ya
resolvió ese problema con evals; el repo A (claude-codex-forge) resolvió el enforcement pero a
costa de acoplarse a Claude Code. La jugada correcta de Phase 2 es **robar la maquinaria de
calidad de B (que es portable) y resistir la tentación de robar los hooks de A (que no lo es)**.

## 1. Top 3 que haría primero (y por qué)

### #1 — Eval framework Tier 1 + Tier 2 (estructural + routing). PORTABLE, barato, alto ROI.
Es lo único en toda la investigación que ataca el problema real de forge-ai: **11 skills que
nadie ha medido**. Con 11 skills, el fallo dominante no es "la skill está mal escrita" sino
"la skill no se dispara cuando debería, o dos skills colisionan" (¿`new-feature` vs `fix-bug`?
¿`plan` vs `research`? ¿`quick-fix` vs `new-feature`?). Tier 1 (lint de frontmatter/secciones)
+ Tier 2 (routing por TF-IDF sobre descriptions con positive/negative prompts) son
**deterministas, sin tokens, corren en CI, y no dependen de ningún engine**. Es literalmente
un script Node/Python que lee `src/skills/*/SKILL.md`. Esto encaja PERFECTO con la identidad
"skills+config": las evals viven en la maquinaria (repo), no en el target.

Concreto: `src/evals/cases/<skill>.json` (3 positive + 2 negative triggers c/u) +
`src/scripts/validate-skills` + `src/scripts/run-evals`. Añadir al `smoke.sh` o un CI mínimo.

### #2 — Anatomía de skill con Anti-Rationalization + Red Flags + Verification.
Este es el patrón de autoría que hace que las skills de B "aguanten presión". forge-ai ya tiene
disciplina fuerte en sus RULES (severity, ship-gates, tdd) pero sus SKILLS probablemente no
tienen la tabla de racionalizaciones que evita que el agente se escape del proceso. Como
forge-ai NO tiene hooks que bloqueen, **la anti-rationalization table ES su enforcement** — es
la única capa que impide que el agente se salte TDD/review "porque es simple". Esto convierte
la debilidad (no-hooks) en una fortaleza de diseño coherente: si no puedes bloquear con hooks,
bloquea con prosa adversarial dentro de la skill. Barato: reescribir 11 skills a la anatomía.

### #3 — Cerrar gaps del catálogo con 3-4 skills de alto valor, NO las 24.
forge-ai no debe convertirse en agent-skills (breadth por breadth traiciona "brutal
simplicity"). Pero hay gaps reales que sus usuarios SÍ tocan:
- **debugging-and-error-recovery** — forge-ai tiene fix-bug pero no una skill de triage
  sistemático reproduce→localize→reduce→fix→guard. Alto valor.
- **security-and-hardening** — hay una rule de security pero no una skill accionable (OWASP,
  secrets, boundary validation). Alto valor para "ship con confianza".
- **doubt-driven-development** — revisión adversarial de decisiones en vuelo. Encaja
  filosóficamente con el cross-engine review de forge-ai.
- **spec-driven-development / interview-me** — forge-ai tiene `prd` pero el loop de
  interrogación "una pregunta a la vez hasta 95% confianza" es superior para pinear intent.

## 2. La tensión del enforcement (lo más importante conceptualmente)

forge-ai apostó a NO hooks por portabilidad. Esa apuesta es CORRECTA y no debe revertirse. Pero
"advisory + native prompt" deja un hueco: nada verifica que los gates estén verdes antes del
push. Tres formas portables de estrechar el hueco SIN traicionar la identidad:

- **(a) Enforcement como script invocado, no como hook.** Un `verify-gates` script que el
  agente corre voluntariamente (la skill se lo ordena) y que lee `state.md`/evidencia y sale
  con código ≠0 si falta un marker. NO es un hook (no intercepta el turn), corre en los 3
  engines, pero da un check binario real en vez de prosa. Esto es el "Tier B" de A hecho
  portable: A lo mete como PreToolUse hook; forge-ai lo mete como paso explícito de la skill
  `finish-branch`.
- **(b) Enforcement en CI, no en el turn.** El gate real de un equipo NO es el agente — es el
  PR. Un GitHub Action que corre las evals + el skill-lint + (opcional) verifica que el PR body
  tenga la evidencia. Portable por definición (corre en el runner, no en el CLI). Esto es más
  honesto que los hooks: los hooks son bypasseables ("it's your machine"); CI no.
- **(c) Tier opcional de hooks POR ENGINE, documentado como add-on.** Para el usuario Claude-only
  que quiere hard gates, shippear un `configs/claude/hooks/` opcional (el usuario opta). NO por
  defecto, NO en el path portable. Documentar claramente "esto te ata a Claude Code". Esto
  recupera lo mejor de A sin imponerlo.

Mi recomendación: **(b) primero (CI), (a) segundo (verify-gates script), (c) solo si hay
demanda.** El PR es el gate honesto.

## 3. Calidad de las skills — versión mínima que vale la pena

SÍ adoptar, en este orden de esfuerzo creciente:
1. **skill-lint** (Tier 1) — 1 script, ~1 día. Chequea frontmatter (`name` == dir, description
   con "what+when" ≤1024, secciones requeridas). Corre en CI.
2. **routing evals** (Tier 2) — 1 script + 11 JSON de casos, ~2-3 días. Detecta colisiones
   (crítico con skills que se solapan como new-feature/fix-bug/quick-fix).
3. **anti-rationalization anatomy** — reescribir las 11 skills, ~2-3 días. Es el enforcement
   de un sistema sin hooks.
4. **behavioral evals (Tier 3)** — DIFERIR. Cuesta tokens, necesita fixtures, y su valor
   incremental sobre Tier 1+2 es menor para un catálogo de 11. Además su implementación en B
   usa `claude -p` — para forge-ai (cross-engine) habría que decidir si se corre por engine.
   Es el candidato natural para "Phase 3".

## 4. Gaps del catálogo — qué SÍ y qué NO

SÍ (llenan gaps reales, encajan con la filosofía): debugging-and-error-recovery,
security-and-hardening, doubt-driven-development, spec-driven-development/interview-me (fusionar
con `prd`), code-simplification (forge-ai ya usa `/simplify` de superpowers? verificar), quizá
observability como RULE no skill.

NO (fuera de scope / traicionan brutal-simplicity): frontend-ui-engineering (ya hay ui-design
plugins), performance-optimization (nicho), deprecation-and-migration (nicho),
browser-testing-with-devtools (Claude-specific MCP), shipping-and-launch/ci-cd (mejor como
rules/checklists que como skills). Las 24 de B están dimensionadas para una lib genérica de
79k estrellas; forge-ai es una espina dorsal opinada, no un catálogo.

## 5. Distribución y adopción

- **`npx skills`-compatibilidad**: agent-skills instala en 70+ agentes vía la CLI de
  vercel-labs/skills porque sus skills son SKILL.md plano. forge-ai YA genera SKILL.md — hacerlo
  compatible con `npx skills add jualopezmo/forge-ai` es casi gratis y multiplica alcance.
- **Claude marketplace plugin**: bajo esfuerzo (un `plugin.json` + `marketplace.json`), pero
  OJO — eso es el path Claude-only, tensión con la identidad cross-engine. Ofrecerlo como UNO
  de varios installs, no EL install.
- **Per-tool setup docs**: A y B ambos tienen docs por herramienta. forge-ai debería tener
  `docs/setup/{claude,codex,opencode}.md`. Barato, alto valor de adopción.
- El thin-installer actual es un buen diferenciador; no romperlo.

## 6. Qué NO hacer (trampas)

- **NO adoptar los hooks de A por defecto.** Mata la portabilidad, que es el único
  diferenciador real de forge-ai frente a A y B.
- **NO inflar a 24 skills.** Breadth mata el foco. La ventaja de forge-ai es ser una espina
  dorsal opinada de 11-15 skills, no un supermercado.
- **NO copiar `/goal` autónomo todavía.** Es potente pero es la feature más frágil de A
  (el CHANGELOG de A está lleno de field-hits donde `/goal` se colgó en prompts de permiso).
  Requiere la maquinaria de evidencia+hooks que forge-ai deliberadamente no tiene. Diferir.
- **NO construir Tier 3 evals antes que Tier 1+2.** Es la parte cara con menor ROI marginal.
- **NO acoplar la investigación a "más review".** La lección de A es "dos modelos con fallos
  distintos", no "más pasadas". forge-ai ya tiene cross-engine review — reforzar eso, no añadir
  capas.

## Resumen ejecutivo
Roba de **B**: evals (Tier 1+2), skill-lint, anti-rationalization anatomy, 3-4 skills puntuales,
`npx skills` compat. Roba de **A**: solo el *concepto* de gate honesto — pero impleméntalo como
**CI + script invocado**, no como hooks. Resiste: hooks-por-defecto, 24 skills, `/goal`,
Tier 3 antes de tiempo.
