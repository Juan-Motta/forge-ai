# Extending forge-ai

How to add capability while keeping the project simple and interoperable across
**Claude Code, Codex, and OpenCode**.

## The rule of thumb

> A **skill** can express anything the agent *should do* (an instruction). A
> **script/hook** is needed only when something must *happen regardless* — block an
> action, run outside the agent's turn, or compute deterministically without relying on
> the model to comply.

Prefer the lowest tier that does the job. Higher tiers add power but cost simplicity and
portability.

---

## Tier A — Skills only (advisory, fully portable)

Anything that is a *procedure or criterion*. Add these freely — no config changes, and all
three engines pick them up automatically via the existing symlinks.

Examples:

- New workflow skills (any command/flow).
- A research step before designing ("investigate and write the brief").
- Cross-engine review ("have the other engine review this plan/diff").
- Severity rubric, TDD sequence, approach comparison, PR-description format.
- "Verify by exercising it."
- A lightweight multi-engine council (a skill that orchestrates calling several engines
  and synthesizing).
- Checklists and keeping `.workflow/state.md` updated.

**Cost:** the agent does it *because instructed*. Nothing prevents non-compliance.

### How to add a skill

1. `mkdir skills/<name>` — the directory name must be lowercase, hyphen-separated.
2. Create `skills/<name>/SKILL.md` (uppercase filename) with frontmatter:
   ```
   ---
   name: <name>          # must equal the directory name
   description: <1–1024 chars; when to use it>
   ---
   ```
   then the steps, referencing `shared/rules/*` and `.workflow/state.md`.
3. Done. The three symlinks (`.claude/skills`, `.codex/skills`, `.opencode/skills` →
   `../skills`) mean every engine discovers it. No further config.

**Framework vs project-own skills:** `skills/` holds both. The installer's `--upgrade`
refreshes only the **framework's own** skills (by name) and never deletes the rest — so a
skill you add here survives upgrades. (Same for `shared/rules/`.) Give your own skills
names distinct from the framework's, or an upgrade will overwrite the collision.

---

## Tier B — Skills + agent-invoked scripts (deterministic, still advisory)

No hooks. A skill tells the agent to run a helper script (e.g. `scripts/check-gates.sh`).
You gain determinism and reuse; a single POSIX script serves all three engines. But it
runs **only when the agent chooses to call it**.

Good fits:

- A `.workflow/state.md` validator (are the required boxes checked?).
- A reproducible git/drift check.
- An artifact checker that *reports* (not blocks) whether a brief/evidence file exists.

**Cost:** deterministic, but still skippable — the agent may not invoke it.

Convention: keep such scripts in `scripts/`, POSIX `sh`, no engine-specific assumptions,
and have the relevant skill name the exact command to run.

---

## Tier C — Hooks (automatic, blocking, or out-of-turn) — NOT portable

Needed only when something must be *guaranteed* — it cannot be expressed as an
instruction. This is where interoperability breaks: each engine has a different mechanism,
so it means maintaining up to three implementations.

Capabilities that require this tier:

- **Conditional blocking** of commit/push/PR based on `.workflow/state.md` (the native
  `permission` gates only do "always ask", not "block *if* gates are unmet").
- **Unbypassable evidence gate** / per-iteration clean evidence / a convergence breaker.
- **A mandatory research gate** (cannot start design until the brief exists).
- **Out-of-turn events:** per-turn phase reminder, dynamic session-start injection,
  pre-compaction save, post-edit auto-format, auto-approve of local writes.

Per-engine mechanism (all can block):

| Engine | Mechanism | Block signal |
| --- | --- | --- |
| Claude Code | hooks in `.claude/settings.json` | `PreToolUse` exit code 2 |
| Codex | `hooks.json` (`$CODEX_HOME` or `<repo>/.codex/hooks.json`) | `PreToolUse` exit code 2 |
| OpenCode | plugin with `tool.execute.before` | throw to abort |

**Trade:** three separate implementations to keep in sync, plus per-engine trust/merge
concerns. This is deliberately out of the current build. Reach for it only when a real
guarantee is worth that cost — and consider starting with a single engine.

---

## Decision checklist

Before adding something, ask in order:

1. Is it a procedure the agent should follow? → **Tier A** (a skill).
2. Does it need deterministic, repeatable computation, but only when asked? → **Tier B**
   (a skill that invokes a `scripts/` helper).
3. Must it be enforced/automatic even if the agent doesn't cooperate, or run outside a
   turn? → **Tier C** (hooks, per engine) — accept the portability cost, or scope to one
   engine.

Default to the lowest tier that works. Most new functionality is Tier A.
