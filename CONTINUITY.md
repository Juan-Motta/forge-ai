# Continuity — session handoff

> The first thing to read on a new session (auto-loaded via `CLAUDE.md` / `AGENTS.md`).
> Keep it current; refresh it with the `checkpoint` skill before closing a session.

- **Focus:** Restructured the repo into a payload/`template/` split — the shippable
  discipline now lives under `template/`, separated from forge-ai's own dev/meta files at
  the root. Goal: developing forge-ai with an agent no longer risks mixing dev config or
  session state into the installable payload.
- **Next step:** Review the branch `refactor/template-payload-split`, then decide whether to
  commit. Remaining verification: (a) open the repo root in each engine and confirm the thin
  root `CLAUDE.md` + root `.claude/settings.json` behave as the dev config (no dogfooding —
  root has no skills symlink by design); (b) run `install.sh` into a fresh real project once
  and open it in each engine end-to-end (temp-dir dry-run already passes: symlinks + skill
  discovery + AGENTS.md all resolve, upgrade preserves PROJECT.md + custom skills).
- **Blockers:** none
- **Active workflow:** none
- **Updated:** 2026-07-16

## Handoff notes

Layout after the split:
- `template/` = payload (`CLAUDE.md`, `skills/`, `shared/rules/`, `.claude/settings.json`,
  `.codex/config.toml`, `opencode.json`, `*.template.md`, `docs/extending.md` + empty docs
  scaffold). No symlinks inside `template/` — `install.sh` creates `AGENTS.md → CLAUDE.md`
  and `.<engine>/skills → ../skills` in the target after copying.
- Root = framework repo files: `install.sh`, `README.md`, `LICENSE`, a thin dev `CLAUDE.md`,
  a minimal `.claude/settings.json` (push/PR gate only, no skills symlink — config mínima
  separada, no dogfooding), `PROJECT.md`, `CONTINUITY.md`, and this repo's own `docs/`
  (CHANGELOG, adr/, design notes, index.md).
- `.gitignore` hardened: `.claude/local/`, `.claude/settings.local.json`, and OpenCode
  local npm cruft are ignored so agent runtime state never gets committed. `install.sh` now
  propagates the local-state ignores into the target's `.gitignore` too.
- Fixed as a side effect: the earlier materialized/broken symlinks in this working copy are
  gone (template/ is symlink-free; symlinks exist only in installed targets).

Docs updated to match: `README.md` (canonical-source + repo-layout sections), `docs/index.md`
(payload vs repo tables), `PROJECT.md` (project info + rule paths → `template/…`).
