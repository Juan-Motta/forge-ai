# claude-gate-hook.ps1 — Claude Code PreToolUse adapter (opt-in Tier-C hardening).
#
# PowerShell parity of claude-gate-hook.sh. Installed only by `install.ps1 -WithHooks`
# into .claude/settings.local.json. On a Bash ship action it runs check-gates.ps1 and
# exits 2 (BLOCK) if the ship-gate boxes are incomplete. Claude Code only, per-developer
# opt-in, not portable. Fails OPEN if it can't verify. See shared/rules/ship-gates.md.
$ErrorActionPreference = "Stop"

# NOTE: read into a non-reserved variable — assigning to the automatic $input in -File mode
# yields an empty string, which silently turned this hook into a no-op.
$payload = [Console]::In.ReadToEnd()

if ($payload -notmatch 'git commit|git push|gh pr create') { exit 0 }

$hookDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$gates = Join-Path $hookDir 'check-gates.ps1'
if (-not (Test-Path -LiteralPath $gates -PathType Leaf)) {
    [Console]::Error.WriteLine("codeforge gate-hook: check-gates.ps1 not found next to the hook; allowing (fail-open).")
    exit 0
}

& pwsh -NoProfile -File $gates *> $null
$rc = $LASTEXITCODE
if ($rc -eq 0) { exit 0 }   # gates complete → allow
if ($rc -ne 1) {            # can't verify (e.g. no workflow state, exit 3) → fail OPEN, never block
    [Console]::Error.WriteLine("codeforge gate-hook: could not verify gates (check-gates exit $rc); allowing (fail-open).")
    exit 0
}

[Console]::Error.WriteLine("codeforge gate: ship BLOCKED — ship-gate boxes are not complete.")
$detail = & pwsh -NoProfile -File $gates 2>&1
foreach ($line in $detail) { [Console]::Error.WriteLine("  $line") }
[Console]::Error.WriteLine("  (opt-in -WithHooks gate; Claude Code only. Finish the boxes in")
[Console]::Error.WriteLine("   .workflow/state.md, then retry. This checks the record, not the work.)")
exit 2
