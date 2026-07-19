# tools/ — framework dev tooling

Dev-only quality machinery for forge-ai itself. **Never shipped into a target project** —
the payload stays skills + config. Node built-ins only, no dependencies.

## Skill linter (`lint-skills.mjs`)

Structural + forge-ai-bespoke lint over `src/skills/*/SKILL.md`. Exit 1 on any error.

```bash
node tools/lint-skills.mjs          # full report
node tools/lint-skills.mjs --quiet  # errors only
npm run lint:skills
```

**Hard rules (errors):**

- Each skill has a `SKILL.md` with valid `--- name / description ---` frontmatter.
- `name` matches the directory; no duplicate names.
- `description` ≤ 1024 chars and carries a "Use when/for/to…" trigger clause (what + when).
- **Index parity** — every skill is listed in `src/CLAUDE.md`'s skill index and vice versa.
  (`AGENTS.md` is generated from `CLAUDE.md`, so one drift poisons all three engines.)
- **Model-ID quarantine** — a skill must not hard-code a model id (`gpt-…`, `glm-…`,
  `kimi-k…`, `opencode-go/…`, `opus`/`sonnet`/`haiku`). `shared/rules/models.md` is the single
  source. Engine *names* (Claude / Codex / OpenCode) are fine.
- **Reference integrity** — every `shared/…​.md` path a skill mentions exists under `src/`.

**Warnings (do not fail the build):**

- Missing `## Verification` section (tracked by the Phase-2 anatomy retrofit).
- `SKILL.md` over 500 lines (progressive-disclosure budget).

## Tests

```bash
node --test 'tools/test/*.test.mjs'
npm run test:tools
```

Both run in CI (`.github/workflows/ci.yml`) on every push/PR alongside the installer smoke test.
