#!/bin/sh
# check-gates.sh — deterministic ship-gate checklist validator (Tier B).
#
# Reads .workflow/state.md and confirms every ship-gate box for the active
# profile is checked (or explicitly N/A). Exit 0 = the recorded checklist is
# complete; non-zero + a list = unmet boxes.
#
#   sh shared/scripts/check-gates.sh                 # reads .workflow/state.md
#   sh shared/scripts/check-gates.sh path/to/state.md
#
# HONESTY: this verifies the RECORD, not the underlying work. A checked box is an
# *attestation* by whoever checked it — the script confirms the checklist is
# complete, it cannot confirm the tests really passed or the change was really
# exercised. See shared/rules/ship-gates.md (Verified / Attested / Advisory).
# It runs only when the agent (or a human, or CI) chooses to call it — Tier B is
# deterministic but still advisory; it does not block a commit on its own.
#
# Exit codes: 0 = complete · 1 = unmet boxes · 3 = cannot read state/checklist.
set -eu

STATE="${1:-.workflow/state.md}"

if [ ! -f "$STATE" ]; then
  echo "check-gates: no state file at '$STATE' — cannot verify gates." >&2
  echo "  Start a workflow (copy shared/state.template.md) before shipping." >&2
  exit 3
fi

profile=$(sed -n 's/.*[Pp]rofile:[*]*[[:space:]]*\([A-Za-z][A-Za-z-]*\).*/\1/p' "$STATE" | head -n1)
[ -n "$profile" ] || profile="(unknown)"

# Walk only the "## Ship-gate checklist" section; tally checked vs unmet boxes.
# A box is unmet only when it is literally "- [ ]" (unchecked). "- [x]" counts as
# satisfied, including an "- [x] ... N/A: <reason>" line. Counts come out on one
# line (kept free of embedded newlines); the unmet box text is a separate pass.
counts=$(awk '
  /^##[[:space:]]+Ship-gate checklist/ { inlist = 1; next }
  /^##[[:space:]]/                     { inlist = 0 }
  inlist && /^- \[[ xX]\]/             { total++ }
  inlist && /^- \[ \]/                 { unmet++ }
  END { printf "%d %d", total + 0, unmet + 0 }
' "$STATE")
total=${counts% *}
unmet=${counts#* }

if [ "$total" -eq 0 ]; then
  echo "check-gates: no '## Ship-gate checklist' boxes found in '$STATE'." >&2
  echo "  Is this a real workflow state file?" >&2
  exit 3
fi

# Validate the checklist actually carries the REQUIRED gates for its profile — otherwise a
# state file that deletes required gates (or claims a profile it doesn't satisfy) reads green.
# Required counts mirror shared/rules/ship-gates.md (standard = 6, light = 3).
case "$profile" in
  standard) required=6 ;;
  light)    required=3 ;;
  *)        echo "check-gates: unknown gate profile '$profile' — can't determine required gates." >&2
            echo "  Set Profile to 'standard' or 'light' in the Active workflow section." >&2
            exit 3 ;;
esac
if [ "$total" -lt "$required" ]; then
  echo "check-gates: profile '$profile' requires $required gates but the checklist has only $total —" >&2
  echo "  required ship-gate boxes are missing. Restore them from shared/state.template.md." >&2
  exit 1
fi

if [ "$unmet" -gt 0 ]; then
  echo "check-gates: profile '$profile' — $((total - unmet))/$total boxes checked — UNMET." >&2
  echo "Unchecked ship-gate boxes (do NOT ship):" >&2
  awk '
    /^##[[:space:]]+Ship-gate checklist/ { inlist = 1; next }
    /^##[[:space:]]/                     { inlist = 0 }
    inlist && /^- \[ \]/                 { print "  \342\234\227" substr($0, 6) }
  ' "$STATE" >&2
  echo "Confirms the recorded checklist, not the work itself (ship-gates.md:" >&2
  echo "Verified / Attested / Advisory). Finish the boxes, then re-run." >&2
  exit 1
fi

# --- E2E evidence check (Attested) --------------------------------------------
# If the "E2E verified" box is checked as a real run (not "— N/A: <reason>"),
# require a report under docs/e2e/reports/ that is BOTH fresh on this branch
# (git, not mtime — clone/checkout resets mtimes) AND VERDICT: PASS.
e2e_line=$(awk '
  /^##[[:space:]]+Ship-gate checklist/ { inlist = 1; next }
  /^##[[:space:]]/                     { inlist = 0 }
  inlist && /^- \[[xX]\][[:space:]]+E2E verified/ { print; exit }
' "$STATE")

if [ -n "$e2e_line" ]; then
  case "$e2e_line" in
    *"N/A:"*)
      # N/A escape must carry a non-empty reason.
      reason=$(printf '%s' "$e2e_line" | sed -n 's/.*N\/A:[[:space:]]*\(.*\)$/\1/p')
      if [ -z "$reason" ]; then
        echo "check-gates: 'E2E verified' uses 'N/A:' with no reason — treated as unmet." >&2
        exit 1
      fi
      ;;
    *)
      # Real E2E claim — need a fresh PASS report. Degrade gracefully when git
      # can't resolve a branch point (not a repo, on default branch, no merge-base).
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        default_branch=""
        for b in main master; do
          if git show-ref --verify --quiet "refs/heads/$b"; then default_branch="$b"; break; fi
        done
        current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        base=""
        if [ -n "$default_branch" ] && [ "$current" != "$default_branch" ]; then
          base=$(git merge-base HEAD "$default_branch" 2>/dev/null || echo "")
        fi
        if [ -n "$base" ]; then
          changed=$(git diff --name-only "$base"..HEAD -- docs/e2e/reports/ 2>/dev/null || echo "")
          staged=$(git diff --cached --name-only -- docs/e2e/reports/ 2>/dev/null || echo "")
          untracked=$(git ls-files --others --exclude-standard -- docs/e2e/reports/ 2>/dev/null || echo "")
          found=""
          for f in $changed $staged $untracked; do
            [ -f "$f" ] || continue
            if grep -Eq '^VERDICT:[[:space:]]*PASS([[:space:]]|$)' "$f"; then found="$f"; break; fi
          done
          if [ -z "$found" ]; then
            echo "check-gates: 'E2E verified' is checked, but no report in docs/e2e/reports/ is" >&2
            echo "  both changed on this branch (since $default_branch) and 'VERDICT: PASS'." >&2
            echo "  Run the verify-e2e skill, or use '— N/A: <reason>' for internal/UI-only changes." >&2
            exit 1
          fi
        fi
      fi
      ;;
  esac
fi
# --- end E2E evidence check ---------------------------------------------------

echo "check-gates: profile '$profile' — all $total recorded boxes checked."
echo "Attested-complete: a checked box is an attestation, not independent proof."
exit 0
