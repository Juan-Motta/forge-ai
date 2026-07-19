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

echo "check-gates: profile '$profile' — all $total recorded boxes checked."
echo "Attested-complete: a checked box is an attestation, not independent proof."
exit 0
