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
# When the "E2E verified" box is checked as a real run (not "— N/A: <reason>"),
# bind it to the report PATH NAMED in the box. That named file must EXIST, carry a
# top-level VERDICT: PASS, and (best-effort) be fresh on this branch. A checked box
# NEVER passes the gate without its named PASS report — no silent fail-open. Base is
# auto-detected by closest merge-base among dev/main/master/origin (this repo
# integrates on dev, not main). Freshness uses git, not mtime (clone/checkout resets
# mtimes); it degrades to a stderr note only when no base ref resolves.
e2e_line=$(awk '
  /^##[[:space:]]+Ship-gate checklist/ { inlist = 1; next }
  /^##[[:space:]]/                     { inlist = 0 }
  inlist && /^- \[[xX]\][[:space:]]+E2E verified/ { print; exit }
' "$STATE")

if [ -n "$e2e_line" ]; then
  case "$e2e_line" in
    *"— N/A:"*)
      # N/A escape must carry a non-empty reason.
      reason=$(printf '%s' "$e2e_line" | sed -n 's/.*N\/A:[[:space:]]*\(.*\)$/\1/p')
      if [ -z "$reason" ]; then
        echo "check-gates: 'E2E verified' uses 'N/A:' with no reason — treated as unmet." >&2
        exit 1
      fi
      ;;
    *)
      # 1. Parse the report path named in the box: (report: <PATH>).
      report_path=$(printf '%s' "$e2e_line" | sed -n 's/.*(report:[[:space:]]*\([^)]*\)).*/\1/p' | head -n1)
      report_path=$(printf '%s' "$report_path" | sed 's/[[:space:]]*$//')
      if [ -z "$report_path" ]; then
        echo "check-gates: 'E2E verified' is checked but names no report path." >&2
        echo "  Put the real report path in the box: (report: docs/e2e/reports/<file>.md)." >&2
        exit 1
      fi
      case "$report_path" in
        *"<"*|*">"*)
          echo "check-gates: 'E2E verified' still names the placeholder report path '$report_path'." >&2
          echo "  Replace it with the real report path: (report: docs/e2e/reports/<file>.md)." >&2
          exit 1
          ;;
      esac
      # 2. Require the named file to exist, resolved against the git toplevel (not cwd).
      toplevel=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
      if [ -n "$toplevel" ]; then abs_report="$toplevel/$report_path"; else abs_report="$report_path"; fi
      if [ ! -f "$abs_report" ]; then
        echo "check-gates: 'E2E verified' names report '$report_path' but that file does not exist." >&2
        echo "  Run the verify-e2e skill to produce it, or use '— N/A: <reason>'." >&2
        exit 1
      fi
      # 3. Top-level verdict must be exactly PASS (the FIRST "VERDICT:" line only, so a
      #    per-UC "VERDICT: PASS" below a top-level FAIL can never satisfy the gate).
      first_verdict=$(awk '/^VERDICT:/{print; exit}' "$abs_report")
      if ! printf '%s' "$first_verdict" | grep -Eq '^VERDICT:[[:space:]]+PASS[[:space:]]*$'; then
        echo "check-gates: report '$report_path' top-level verdict is not 'VERDICT: PASS'." >&2
        echo "  The first VERDICT: line must be exactly 'VERDICT: PASS'." >&2
        exit 1
      fi
      # 4. Freshness (best-effort, never silently passes): the named path must be new
      #    work on this branch. Base = closest merge-base among dev/main/master/origin.
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        origin_head=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo "")
        base=""
        best_count=""
        for ref in dev main master origin/dev origin/main origin/master "$origin_head"; do
          [ -n "$ref" ] || continue
          [ "$ref" != "$current" ] || continue
          git rev-parse --verify --quiet "$ref" >/dev/null 2>&1 || continue
          mb=$(git merge-base HEAD "$ref" 2>/dev/null || echo "")
          [ -n "$mb" ] || continue
          count=$(git rev-list --count "$mb"..HEAD 2>/dev/null || echo "")
          [ -n "$count" ] || continue
          if [ -z "$best_count" ] || [ "$count" -lt "$best_count" ]; then
            best_count="$count"; base="$mb"
          fi
        done
        if [ -n "$base" ]; then
          committed=$(git diff --name-only "$base"..HEAD -- "$report_path" 2>/dev/null || echo "")
          staged=$(git diff --cached --name-only -- "$report_path" 2>/dev/null || echo "")
          unstaged=$(git diff --name-only -- "$report_path" 2>/dev/null || echo "")
          untracked=$(git ls-files --others --exclude-standard -- "$report_path" 2>/dev/null || echo "")
          if [ -z "$committed" ] && [ -z "$staged" ] && [ -z "$unstaged" ] && [ -z "$untracked" ]; then
            echo "check-gates: report '$report_path' is not fresh on this branch (base $base)." >&2
            echo "  It is unchanged from the base — a stale or inherited report cannot satisfy the gate." >&2
            echo "  Run the verify-e2e skill to produce a report for THIS change." >&2
            exit 1
          fi
        else
          echo "check-gates: note — no base branch (dev/main/master/origin) resolved; report" >&2
          echo "  freshness could not be checked. Existence + VERDICT: PASS were enforced for '$report_path'." >&2
        fi
      fi
      ;;
  esac
fi
# --- end E2E evidence check ---------------------------------------------------

echo "check-gates: profile '$profile' — all $total recorded boxes checked."
echo "Attested-complete: a checked box is an attestation, not independent proof."
exit 0
