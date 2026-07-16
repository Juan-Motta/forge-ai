# forge-ai — framework repo (development config)

> This is the forge-ai framework **itself**, not a project that has forge-ai installed.
> It is intentionally minimal — the shippable discipline lives in `template/`, not here.

## Layout

- **`template/`** — the installable payload. `install.sh` copies its contents into a target
  project's root. Editing files here changes **what gets shipped**; they are NOT loaded as
  instructions for *this* repo — they only take effect once installed into a target.
- **`install.sh`, `README.md`, `LICENSE`** — the framework's own tooling and docs.
- **`PROJECT.md`, `CONTINUITY.md`, `docs/`** — this repo's own project rules, session
  handoff, and history (ADRs, changelog, design notes).

## Working on forge-ai

- Read `PROJECT.md` (persona, special rules) and `CONTINUITY.md` (current focus / next
  step) first.
- **Never work on `main`** — branch first. **No git worktrees** (simple branch). **No
  `Co-Authored-By` trailer** on commits.
- To change the framework's behavior, edit the payload under `template/shared/rules/` and
  `template/skills/` — that is the source of truth for what forge-ai ships.
- Keep this file thin: dev orientation only. The discipline is in `template/`, by design.
