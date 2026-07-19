#!/bin/sh
# claude-gate-hook.sh — Claude Code PreToolUse adapter (opt-in Tier-C hardening).
#
# Installed only by `install.sh --with-hooks` into .claude/settings.local.json. On a
# Bash ship action (git commit / git push / gh pr create) it runs check-gates.sh; if
# the ship-gate boxes are incomplete it exits 2, which Claude Code treats as a BLOCK.
# This is the one place forge-ai can HARD-block — Claude Code only, per-developer opt-in,
# not portable. The default install stays advisory. See shared/rules/ship-gates.md.
#
# Reads the tool call as JSON on stdin. Fails OPEN (never blocks) if it can't verify —
# an opt-in convenience must not brick a commit when the install is incomplete.
set -eu

input="$(cat)"

# Only gate outward ship actions. Match the raw payload (escaping-robust); the
# PreToolUse matcher already scopes this to Bash calls.
case "$input" in
  *'git commit'*|*'git push'*|*'gh pr create'*) : ;;
  *) exit 0 ;;
esac

hook_dir="$(cd "$(dirname "$0")" && pwd)"
gates="$hook_dir/check-gates.sh"
if [ ! -f "$gates" ]; then
  echo "forge-ai gate-hook: check-gates.sh not found next to the hook; allowing (fail-open)." >&2
  exit 0
fi

rc=0
sh "$gates" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then exit 0; fi        # gates complete → allow
if [ "$rc" -ne 1 ]; then                    # can't verify (e.g. no state, exit 3) → fail OPEN
  echo "forge-ai gate-hook: could not verify gates (check-gates exit $rc); allowing (fail-open)." >&2
  exit 0
fi

# rc == 1: ship-gate incomplete → block with the detail.
echo "forge-ai gate: ship BLOCKED — ship-gate boxes are not complete." >&2
sh "$gates" 2>&1 | sed 's/^/  /' >&2 || true
echo "  (opt-in --with-hooks gate; Claude Code only. Finish the boxes in" >&2
echo "   .workflow/state.md, then retry. This checks the record, not the work.)" >&2
exit 2
