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

Write-Output "check-gates: profile '$profile' — all $total recorded boxes checked."
Write-Output "Attested-complete: a checked box is an attestation, not independent proof."
exit 0
