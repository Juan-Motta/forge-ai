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
# Parity with sh's masked git failures (`|| echo ""` / `2>$null`): on a pwsh where
# $PSNativeCommandUseErrorActionPreference defaults to $true, an expected non-zero exit
# from a native command (git show-ref / merge-base / diff / ls-files below) would THROW
# under $ErrorActionPreference = "Stop" and abort as a false BLOCK. Disable it so native
# git non-zero exits are handled via $LASTEXITCODE, exactly like the sh side.
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
        $inRepo = $false
        try { git rev-parse --is-inside-work-tree *> $null; if ($LASTEXITCODE -eq 0) { $inRepo = $true } } catch {}
        if ($inRepo) {
            $default = ''
            foreach ($b in 'main','master') {
                git show-ref --verify --quiet "refs/heads/$b" *> $null
                if ($LASTEXITCODE -eq 0) { $default = $b; break }
            }
            $current = (git rev-parse --abbrev-ref HEAD 2>$null)
            $base = ''
            if ($default -and $current -ne $default) { $base = (git merge-base HEAD $default 2>$null) }
            if ($base) {
                $changed   = (git diff --name-only "$base..HEAD" -- docs/e2e/reports/ 2>$null)
                $staged    = (git diff --cached --name-only -- docs/e2e/reports/ 2>$null)
                $untracked = (git ls-files --others --exclude-standard -- docs/e2e/reports/ 2>$null)
                $cands = @($changed) + @($staged) + @($untracked) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
                $found = $false
                foreach ($f in $cands) {
                    # Anchor to the TOP-LEVEL verdict: only the FIRST "VERDICT:" line counts, so a
                    # per-UC "VERDICT: PASS" below a top-level FAIL can never satisfy the gate.
                    $fv = (Get-Content -LiteralPath $f | Where-Object { $_ -cmatch '^VERDICT:' } | Select-Object -First 1)
                    if ($fv -cmatch '^VERDICT:\s*PASS(\s|$)') { $found = $true; break }
                }
                if (-not $found) {
                    [Console]::Error.WriteLine("check-gates: 'E2E verified' is checked, but no report in docs/e2e/reports/ is")
                    [Console]::Error.WriteLine("  both changed on this branch (since $default) and 'VERDICT: PASS'.")
                    [Console]::Error.WriteLine("  Run the verify-e2e skill, or use '— N/A: <reason>' for internal/UI-only changes.")
                    exit 1
                }
            }
        }
    }
}
# --- end E2E evidence check ---------------------------------------------------

Write-Output "check-gates: profile '$profile' — all $total recorded boxes checked."
Write-Output "Attested-complete: a checked box is an attestation, not independent proof."
exit 0
