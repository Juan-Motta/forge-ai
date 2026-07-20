# check-gates.ps1 — deterministic ship-gate checklist validator (Tier B).
#
# PowerShell parity of shared/scripts/check-gates.sh. Reads .workflow/state.md and
# confirms every ship-gate box for the active profile is checked (or N/A).
#
#   pwsh shared/scripts/check-gates.ps1                 # reads .workflow/state.md
#   pwsh shared/scripts/check-gates.ps1 path\to\state.md
#
# HONESTY: verifies the RECORD, not the underlying work — a checked box is an
# attestation, not proof. See shared/rules/ship-gates.md (Verified / Attested /
# Advisory). Advisory (Tier B): it does not block a commit on its own.
#
# Exit codes: 0 = complete · 1 = unmet boxes · 3 = cannot read state/checklist.
[CmdletBinding()]
param([string]$StatePath = ".workflow/state.md")

$ErrorActionPreference = "Stop"
# Parity with sh's masked git failures (`|| echo ""` / `2>$null`): explicitly set
# $PSNativeCommandUseErrorActionPreference = $false (defensive: guards against upstream
# configs that enable it) so native git non-zero exits are handled via $LASTEXITCODE, not thrown.
$PSNativeCommandUseErrorActionPreference = $false

if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
    [Console]::Error.WriteLine("check-gates: no state file at '$StatePath' — cannot verify gates.")
    [Console]::Error.WriteLine("  Start a workflow (copy shared/state.template.md) before shipping.")
    exit 3
}

$lines = Get-Content -LiteralPath $StatePath

$profile = "(unknown)"
foreach ($line in $lines) {
    $m = [regex]::Match($line, 'Profile:[*]*\s*([A-Za-z][A-Za-z-]*)')
    if ($m.Success) { $profile = $m.Groups[1].Value; break }
}

$inList = $false
$total = 0
$unmetLines = @()
foreach ($line in $lines) {
    if ($line -match '^##\s+Ship-gate checklist') { $inList = $true; continue }
    elseif ($line -match '^##\s')                 { $inList = $false }
    if (-not $inList) { continue }
    if ($line -match '^- \[[ xX]\]') { $total++ }
    if ($line -match '^- \[ \]')     { $unmetLines += ("  " + [char]0x2717 + $line.Substring(5)) }
}

if ($total -eq 0) {
    [Console]::Error.WriteLine("check-gates: no '## Ship-gate checklist' boxes found in '$StatePath'.")
    [Console]::Error.WriteLine("  Is this a real workflow state file?")
    exit 3
}

# Validate the checklist carries the REQUIRED gates for its profile (standard = 6, light = 3,
# per shared/rules/ship-gates.md) — otherwise a state file that deletes gates reads green.
$required = switch ($profile) {
    'standard' { 6; break }
    'light'    { 3; break }
    default {
        [Console]::Error.WriteLine("check-gates: unknown gate profile '$profile' — can't determine required gates.")
        [Console]::Error.WriteLine("  Set Profile to 'standard' or 'light' in the Active workflow section.")
        exit 3
    }
}
if ($total -lt $required) {
    [Console]::Error.WriteLine("check-gates: profile '$profile' requires $required gates but the checklist has only $total —")
    [Console]::Error.WriteLine("  required ship-gate boxes are missing. Restore them from shared/state.template.md.")
    exit 1
}

$unmet = $unmetLines.Count
if ($unmet -gt 0) {
    [Console]::Error.WriteLine("check-gates: profile '$profile' — $($total - $unmet)/$total boxes checked — UNMET.")
    [Console]::Error.WriteLine("Unchecked ship-gate boxes (do NOT ship):")
    foreach ($l in $unmetLines) { [Console]::Error.WriteLine($l) }
    [Console]::Error.WriteLine("Confirms the recorded checklist, not the work itself (ship-gates.md:")
    [Console]::Error.WriteLine("Verified / Attested / Advisory). Finish the boxes, then re-run.")
    exit 1
}

# --- E2E evidence check (Attested) --------------------------------------------
$e2eLine = $null
$inE = $false
foreach ($line in $lines) {
    if ($line -match '^##\s+Ship-gate checklist') { $inE = $true; continue }
    elseif ($line -match '^##\s')                 { $inE = $false }
    if ($inE -and $line -cmatch '^- \[[xX]\]\s+E2E verified') { $e2eLine = $line; break }
}
if ($e2eLine) {
    if ($e2eLine -cmatch '— N/A:') {
        $reason = ([regex]::Match($e2eLine, 'N/A:\s*(.*)$')).Groups[1].Value.Trim()
        if ([string]::IsNullOrEmpty($reason)) {
            [Console]::Error.WriteLine("check-gates: 'E2E verified' uses 'N/A:' with no reason — treated as unmet.")
            exit 1
        }
    } else {
        # 0. Reject an ambiguous line carrying more than one "(report:" group — one report
        #    per box. Without this, sh's greedy extraction (rightmost group) and ps1's
        #    leftmost-first regex Match could disagree on WHICH path is checked; refusing
        #    the ambiguous line outright removes the divergence entirely.
        $reportGroups = ([regex]::Matches($e2eLine, '\(report:')).Count
        if ($reportGroups -gt 1) {
            [Console]::Error.WriteLine("check-gates: 'E2E verified' line names more than one (report: ...) group — ambiguous.")
            [Console]::Error.WriteLine("  A checked box must name exactly one report.")
            exit 1
        }
        # 1. Parse the report path named in the box: (report: <PATH>).
        $reportPath = ''
        $mrp = [regex]::Match($e2eLine, '\(report:\s*([^)]*)\)')
        if ($mrp.Success) { $reportPath = $mrp.Groups[1].Value.TrimEnd() }
        if ([string]::IsNullOrEmpty($reportPath)) {
            [Console]::Error.WriteLine("check-gates: 'E2E verified' is checked but names no report path.")
            [Console]::Error.WriteLine("  Put the real report path in the box: (report: docs/e2e/reports/<file>.md).")
            exit 1
        }
        # 1b. Whitelist the path shape: it must be a bare filename directly under
        #     docs/e2e/reports/ — no '..', no subdirectories, no absolute paths. Since '<'
        #     and '>' fall outside the allowed charset, this also subsumes the previous
        #     placeholder-only rejection with one strict allowlist.
        if ($reportPath -cnotmatch '^docs/e2e/reports/[A-Za-z0-9._-]+\.md$') {
            [Console]::Error.WriteLine("check-gates: 'E2E verified' names report path '$reportPath', which is not a")
            [Console]::Error.WriteLine("  real report under docs/e2e/reports/. The box must name a real file directly")
            [Console]::Error.WriteLine("  under docs/e2e/reports/ (e.g. docs/e2e/reports/<feature>.md) — no '..', no")
            [Console]::Error.WriteLine("  subdirectories, no absolute paths, no placeholders.")
            exit 1
        }
        # 2. Resolve against the git toplevel (not cwd), and require a REGULAR FILE — a
        #    symlink at the named path (e.g. pointing outside the repo at a fabricated
        #    report) must never satisfy the gate. Checked BEFORE the existence check so a
        #    symlink can never count as "exists".
        $toplevel = (git rev-parse --show-toplevel 2>$null)
        if ($toplevel) { $absReport = Join-Path $toplevel $reportPath } else { $absReport = $reportPath }
        $absItem = Get-Item -LiteralPath $absReport -Force -ErrorAction SilentlyContinue
        if ($absItem -and $absItem.LinkType) {
            [Console]::Error.WriteLine("check-gates: 'E2E verified' names report '$reportPath' but that path is a")
            [Console]::Error.WriteLine("  symlink, not a regular file. Reports must be real files under docs/e2e/reports/.")
            exit 1
        }
        if (-not (Test-Path -LiteralPath $absReport -PathType Leaf)) {
            [Console]::Error.WriteLine("check-gates: 'E2E verified' names report '$reportPath' but that file does not exist.")
            [Console]::Error.WriteLine("  Run the verify-e2e skill to produce it, or use '— N/A: <reason>'.")
            exit 1
        }
        # 3. Top-level verdict must be exactly PASS (the FIRST "VERDICT:" line only, so a
        #    per-UC "VERDICT: PASS" below a top-level FAIL can never satisfy the gate).
        $firstVerdict = (Get-Content -LiteralPath $absReport | Where-Object { $_ -cmatch '^VERDICT:' } | Select-Object -First 1)
        if (-not ($firstVerdict -cmatch '^VERDICT:\s+PASS\s*$')) {
            [Console]::Error.WriteLine("check-gates: report '$reportPath' top-level verdict is not 'VERDICT: PASS'.")
            [Console]::Error.WriteLine("  The first VERDICT: line must be exactly 'VERDICT: PASS'.")
            exit 1
        }
        # 4. Freshness (best-effort, never silently passes): the named path must be new
        #    work on this branch. Base = closest merge-base among dev/main/master/origin.
        $inRepo = $false
        try { git rev-parse --is-inside-work-tree *> $null; if ($LASTEXITCODE -eq 0) { $inRepo = $true } } catch {}
        if ($inRepo) {
            $current = (git rev-parse --abbrev-ref HEAD 2>$null)
            $originHead = (git rev-parse --abbrev-ref origin/HEAD 2>$null)
            $base = ''
            $bestCount = -1
            $cands = @('dev','main','master','origin/dev','origin/main','origin/master')
            if ($originHead) { $cands += $originHead }
            foreach ($ref in $cands) {
                if (-not $ref) { continue }
                if ($ref -eq $current) { continue }
                git rev-parse --verify --quiet $ref *> $null
                if ($LASTEXITCODE -ne 0) { continue }
                $mb = (git merge-base HEAD $ref 2>$null)
                if (-not $mb) { continue }
                $count = (git rev-list --count "$mb..HEAD" 2>$null)
                if (-not $count) { continue }
                $c = [int]$count
                if ($bestCount -lt 0 -or $c -lt $bestCount) { $bestCount = $c; $base = $mb }
            }
            if ($base) {
                $committed = (git diff --name-only "$base..HEAD" -- $reportPath 2>$null)
                $staged    = (git diff --cached --name-only -- $reportPath 2>$null)
                $unstaged  = (git diff --name-only -- $reportPath 2>$null)
                $untracked = (git ls-files --others --exclude-standard -- $reportPath 2>$null)
                if (-not $committed -and -not $staged -and -not $unstaged -and -not $untracked) {
                    [Console]::Error.WriteLine("check-gates: report '$reportPath' is not fresh on this branch (base $base).")
                    [Console]::Error.WriteLine("  It is unchanged from the base — a stale or inherited report cannot satisfy the gate.")
                    [Console]::Error.WriteLine("  Run the verify-e2e skill to produce a report for THIS change.")
                    exit 1
                }
            } else {
                [Console]::Error.WriteLine("check-gates: note — no base branch (dev/main/master/origin) resolved; report")
                [Console]::Error.WriteLine("  freshness could not be checked. Existence + VERDICT: PASS were enforced for '$reportPath'.")
            }
        }
    }
}
# --- end E2E evidence check ---------------------------------------------------

Write-Output "check-gates: profile '$profile' — all $total recorded boxes checked."
Write-Output "Attested-complete: a checked box is an attestation, not independent proof."
exit 0
