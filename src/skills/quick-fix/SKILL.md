---
name: quick-fix
description: Lightweight workflow for trivial changes (fewer than 3 files, no behavior risk) — branch, change, quick check, verify, ship. Use for typos, copy tweaks, small config edits under Claude Code, Codex, or OpenCode. Escalate to new-feature or fix-bug if scope grows.
---

# quick-fix

For genuinely trivial changes only. If the change touches 3+ files, alters behavior, or
turns out non-obvious, **stop and switch** to `new-feature` or `fix-bug`.

## 0. Set up tracking

- Confirm you are **not on `main`** — create a branch (`chore/<name>` or `fix/<name>`).
- A full `.workflow/state.md` is optional here; still record the branch and a one-line
  intent so the ship-gate has context. If you use state.md, set **Profile: light**.

## 1. Make the change

Apply the small edit. Keep it to the stated scope — no drive-by refactors.

## 2. Quick check

- If code with a runtime effect: add or run a relevant test.
- If docs/config: sanity-check syntax and that nothing references the old value.

## 3. Verify

Exercise the changed path (or render the doc / load the config) and confirm the intended
result. Trivial does not mean unverified.

## 4. Ship

Commit, then push / open PR. The native approval prompt on push/PR still applies — approve
only if the change is truly complete and correct.

> Scope guard: the moment this stops feeling trivial, abandon quick-fix and restart under
> `new-feature` / `fix-bug` with the full discipline.
