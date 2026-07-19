#!/usr/bin/env pwsh
#
# forge-ai installer (Windows / PowerShell) — copy the workflow discipline into a target
# project. Mirror of install.sh.
#
#   pwsh ./install.ps1 [target-dir] [-Upgrade] [-WithHooks] [-GitInit]
#
# With no target-dir, installs into the current working directory.
#
# THIN INSTALL: the target receives only what the agent needs at RUNTIME. All framework
# machinery (the neutral source in ./src/, the generators sync.sh/ps1, the generation
# inputs in configs/, and the seed templates) stays in the forge-ai repo — never copied
# into the target. To customize or upgrade, edit the forge-ai source and re-run this
# installer against the target (-Upgrade, or a bare re-run from inside the project).
#
# This installer copies the runtime subset into the target, then runs `sync.ps1 -Out <target>`
# to GENERATE each engine's config + skills straight into the target. No symlinks. The
# generated engine artifacts are COMMITTED with the target so a fresh clone works with no
# forge-ai dependency at runtime.
#
# LANDS IN THE TARGET (runtime only): CLAUDE.md, AGENTS.md, opencode.json, .claude/,
#   .agents/, .codex/ (generated), shared/rules/*.md + shared/state.template.md + shared/scripts/* (managed),
#   docs/ scaffolding + CHANGELOG, PROJECT.md + CONTINUITY.md (project-owned, seeded).
# STAYS IN forge-ai (never copied): src/skills (neutral), configs/, sync.sh, sync.ps1,
#   *.template.md, docs/extending.md.
#
param(
  [Parameter(Mandatory = $false)][string]$Target,
  [switch]$Upgrade,
  [switch]$WithHooks,
  [switch]$GitInit
)
$ErrorActionPreference = 'Stop'

$Src = Split-Path -Parent $MyInvocation.MyCommand.Path
$Payload = Join-Path $Src 'src'
$forgeVersion = "unknown"
$versionFile = Join-Path $Src 'VERSION'
if (Test-Path -LiteralPath $versionFile -PathType Leaf) {
  $v = (Get-Content -LiteralPath $versionFile -TotalCount 1)
  if ($v) { $forgeVersion = $v.Trim() }
}
$Mode = if ($Upgrade) { 'upgrade' } else { 'install' }
if (-not $Target) { $Target = (Get-Location).Path }

if (-not (Test-Path -PathType Container $Target)) { Write-Error "target dir not found: $Target"; exit 2 }
$Target = (Resolve-Path $Target).Path
if (-not ((Test-Path (Join-Path $Payload 'CLAUDE.md')) -and (Test-Path (Join-Path $Payload 'skills')))) {
  Write-Error "payload not found — run this from the forge-ai repo"; exit 2
}
if ($Target -eq $Src) { Write-Error "refusing to install into forge-ai itself"; exit 2 }
if ($Target -eq $Payload) { Write-Error "refusing to install into the forge-ai payload dir (src/)"; exit 2 }

Write-Host "forge-ai $forgeVersion -> installing into: $Target  (mode: $Mode)"

# --- version drift advisory (informational only, never blocks) ---
$priorVersion = ""
$fvFile = Join-Path $Target '.forge-version'
if (Test-Path -LiteralPath $fvFile -PathType Leaf) {
  $pv = (Get-Content -LiteralPath $fvFile -TotalCount 1)
  if ($pv) { $priorVersion = $pv.Trim() }
}
if ($priorVersion -and $priorVersion -ne $forgeVersion -and $forgeVersion -ne 'unknown' -and $priorVersion -ne 'unknown') {
  try { $isUpgrade = ([version]$priorVersion -lt [version]$forgeVersion) }
  catch { $isUpgrade = ($priorVersion -lt $forgeVersion) }
  if ($isUpgrade) {
    Write-Host "  ~ upgrading this target: forge-ai $priorVersion -> $forgeVersion"
  } else {
    Write-Host "  ! this target was installed by a NEWER forge-ai ($priorVersion) than you're running ($forgeVersion)."
    Write-Host "    You may be downgrading it; teammates pinned to $priorVersion could see drift. (advisory only)"
  }
}

function Has-ForgeMarker([string]$file) {
  return (Test-Path $file) -and (Select-String -Quiet -SimpleMatch 'Workflow discipline for Claude Code' $file)
}

# --- self-healing: drop machinery this version no longer installs into the target ---
# (thin model — migrates a target from an older, bloated install.) Gated on a prior forge
# install (.forge-manifest present) so a FIRST install never touches an unrelated project's
# own configs/ or skills/ dirs.
if (Test-Path (Join-Path $Target '.forge-manifest')) {
  foreach ($f in 'sync.sh', 'sync.ps1', 'state.template.md', 'PROJECT.template.md', 'CONTINUITY.template.md', 'docs/extending.md') {
    $p = Join-Path $Target $f
    if (Test-Path $p) { Remove-Item -Force $p; Write-Host "  - removed obsolete framework file: $f" }
  }
  # configs/ and neutral skills/ may hold pre-forge user edits — back up rather than delete.
  $tConfigs = Join-Path $Target 'configs'
  if (Test-Path -PathType Container $tConfigs) {
    $bak = Join-Path $Target 'configs.pre-forge.bak'
    if (Test-Path $bak) { Remove-Item -Recurse -Force $bak }
    Move-Item $tConfigs $bak
    Write-Host "  ! configs/ is obsolete (engine configs are generated now) -> configs.pre-forge.bak; per-project Claude tweaks go in .claude/settings.local.json"
  }
  $tSkills = Join-Path $Target 'skills'
  if (Test-Path -PathType Container $tSkills) {
    $bak = Join-Path $Target 'skills.pre-forge.bak'
    if (Test-Path $bak) { Remove-Item -Recurse -Force $bak }
    Move-Item $tSkills $bak
    Write-Host "  ! neutral skills/ is obsolete (skills are generated now) -> skills.pre-forge.bak; add custom skills to the forge-ai repo"
  }
}

# --- MANAGED: CLAUDE.md (back up a pre-existing, non-forge one) ---
$tClaude = Join-Path $Target 'CLAUDE.md'
if ((Test-Path $tClaude) -and -not (Has-ForgeMarker $tClaude)) {
  Copy-Item $tClaude "$tClaude.pre-forge.bak" -Force
  Write-Host "  ! backed up existing CLAUDE.md -> CLAUDE.md.pre-forge.bak (move project-specifics into PROJECT.md)"
}
Copy-Item (Join-Path $Payload 'CLAUDE.md') $tClaude -Force

# --- MANAGED: framework shared/rules/ (per-entry overwrite by name) ---
New-Item -ItemType Directory -Force -Path (Join-Path $Target 'shared/rules') | Out-Null
$newRules = @(Get-ChildItem -File (Join-Path $Payload 'shared/rules') -Filter *.md).Name

# Prune framework rules removed upstream (see install.sh for rationale). Project-owned rules
# aren't in the manifest, so they're untouched. No manifest yet = skip prune.
$manifest = Join-Path $Target '.forge-manifest'
if (Test-Path $manifest) {
  foreach ($line in Get-Content $manifest) {
    if ($line -like 'rule:*') {
      $n = $line.Substring(5)
      if ($newRules -notcontains $n) { Remove-Item -Force (Join-Path $Target "shared/rules/$n") -ErrorAction SilentlyContinue; Write-Host "  - pruned framework rule removed upstream: $n" }
    }
  }
}

foreach ($f in Get-ChildItem -File (Join-Path $Payload 'shared/rules') -Filter *.md) {
  Copy-Item $f.FullName (Join-Path $Target "shared/rules/$($f.Name)") -Force
}

# Record the framework-owned manifest for the next upgrade's prune (rules only).
Set-Content -Path $manifest -Value (@($newRules | ForEach-Object { "rule:$_" }))

# Stamp the version that produced this install, for drift detection on the next run.
Set-Content -Path (Join-Path $Target '.forge-version') -Value $forgeVersion

# --- MANAGED: workflow state template (in shared/) ---
Copy-Item (Join-Path $Payload 'shared/state.template.md') (Join-Path $Target 'shared/state.template.md') -Force

# --- MANAGED: framework shared/scripts/ (agent-invoked Tier-B helpers, e.g. check-gates) ---
$scriptsSrc = Join-Path $Payload 'shared/scripts'
if (Test-Path -LiteralPath $scriptsSrc -PathType Container) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Target 'shared/scripts') | Out-Null
  foreach ($f in Get-ChildItem -File $scriptsSrc) {
    Copy-Item $f.FullName (Join-Path $Target "shared/scripts/$($f.Name)") -Force
  }
}

# --- MANAGED: docs/ scaffolding ---
New-Item -ItemType Directory -Force -Path (Join-Path $Target 'docs') | Out-Null
foreach ($d in 'prds', 'plans', 'research', 'solutions', 'adr') {
  $dd = Join-Path $Target "docs/$d"
  New-Item -ItemType Directory -Force -Path $dd | Out-Null
  $gk = Join-Path $dd '.gitkeep'
  if (-not (Test-Path $gk)) { New-Item -ItemType File -Path $gk | Out-Null }
}

# --- PROJECT-OWNED: PROJECT.md / CONTINUITY.md / docs/CHANGELOG.md (create only if missing) ---
$tProject = Join-Path $Target 'PROJECT.md'
if (-not (Test-Path $tProject)) {
  Copy-Item (Join-Path $Payload 'PROJECT.template.md') $tProject
  Write-Host "  + created PROJECT.md (fill in persona/info/variables/special rules)"
}
$tCont = Join-Path $Target 'CONTINUITY.md'
if (-not (Test-Path $tCont)) { Copy-Item (Join-Path $Payload 'CONTINUITY.template.md') $tCont }
$tChangelog = Join-Path $Target 'docs/CHANGELOG.md'
if (-not (Test-Path $tChangelog)) { Copy-Item (Join-Path $Payload 'docs/CHANGELOG.md') $tChangelog }

# --- back up any pre-existing, NON-forge per-engine skills dir before sync overwrites it ---
foreach ($eng in '.claude', '.agents') {
  $sd = Join-Path $Target "$eng/skills"
  if ((Test-Path $sd) -and -not (Test-Path (Join-Path $sd '.forge-generated'))) {
    Move-Item $sd "$sd.pre-forge.bak"
    Write-Host "  ! backed up existing $eng/skills -> $eng/skills.pre-forge.bak (add custom skills to the forge-ai repo)"
  }
}
# back up a real, non-forge AGENTS.md before sync overwrites it
$tAgents = Join-Path $Target 'AGENTS.md'
if ((Test-Path $tAgents) -and -not (Has-ForgeMarker $tAgents)) {
  Copy-Item $tAgents "$tAgents.pre-forge.bak" -Force
  Write-Host "  ! backed up existing AGENTS.md -> AGENTS.md.pre-forge.bak"
}

# --- GENERATE engine dirs + AGENTS.md + opencode.json via sync (reads the forge-ai source,
#     writes straight into the target) ---
& (Join-Path $Src 'src/sync.ps1') -Out $Target | Out-Null

# --- OPT-IN Tier-C: Claude Code hard-block gate hook (only with -WithHooks) ---
if ($WithHooks) {
  $sl = Join-Path $Target '.claude/settings.local.json'
  if (Test-Path -LiteralPath $sl -PathType Leaf) {
    if (Select-String -LiteralPath $sl -Pattern 'claude-gate-hook' -Quiet) {
      Write-Host "  = Claude gate hook already present in .claude/settings.local.json"
    } else {
      Write-Host "  ! .claude/settings.local.json exists — NOT overwriting it. To enable the gate, add a"
      Write-Host "    PreToolUse Bash hook running: pwsh -File `"`$env:CLAUDE_PROJECT_DIR/shared/scripts/claude-gate-hook.ps1`""
    }
  } else {
    $hookJson = @'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "pwsh -NoProfile -File \"$env:CLAUDE_PROJECT_DIR/shared/scripts/claude-gate-hook.ps1\"" }
        ]
      }
    ]
  }
}
'@
    Set-Content -Path $sl -Value $hookJson
    Write-Host "  + Claude gate hook -> .claude/settings.local.json (opt-in, Claude-only, hard-blocks ship on incomplete gates)"
  }
}

# --- .gitignore (merge, don't clobber): ONLY local state (generated files are committed) ---
$gi = Join-Path $Target '.gitignore'
if (-not (Test-Path $gi)) { New-Item -ItemType File -Path $gi | Out-Null }
$marker = '# forge-ai (local state — do not commit)'
if (-not (Select-String -Quiet -SimpleMatch $marker $gi)) {
  $block = @"

# forge-ai (local state — do not commit)
.DS_Store
.workflow/
.claude/settings.local.json
"@
  Add-Content -Path $gi -Value $block
}

# --- warn if the generated config lacks the forge push/PR gate ---
function Warn-Gate([string]$rel, [string]$needle, [string]$hint) {
  $f = Join-Path $Target $rel
  if ((Test-Path $f) -and -not (Select-String -Quiet -SimpleMatch $needle $f)) {
    Write-Host "  ! $rel has no forge push/PR gate ($hint) — add it to the forge-ai source, then re-run."
  }
}
Warn-Gate '.claude/settings.json' 'git push'       'ask-tier on git push / gh pr create'
Warn-Gate '.codex/config.toml'    'approval_policy' 'approval_policy'
Warn-Gate 'opencode.json'         'git push'       'permission.bash git push* / gh pr create*'

# --- post-install validation: generated skill copies + AGENTS.md must exist ---
$ok = $true
foreach ($p in '.claude/skills', '.agents/skills') {
  if (-not (Test-Path (Join-Path $Target "$p/new-feature/SKILL.md"))) {
    Write-Host "  ! discovery FAILED: $p was not generated"; $ok = $false
  }
}
foreach ($f in 'AGENTS.md', '.claude/settings.json', '.codex/config.toml', 'opencode.json', 'shared/state.template.md') {
  if (-not (Test-Path (Join-Path $Target $f))) { Write-Host "  ! FAILED: $f was not generated"; $ok = $false }
}
if (-not $ok) {
  Write-Host "  x install INCOMPLETE — issues above; NOT marking as installed"; exit 1
}
Write-Host "  + validation: skills (.claude + .agents), AGENTS.md, and engine configs generated"

# --- git: the workflow (branches/commits) and ship gates operate on git ---
& git -C $Target rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -eq 0) {
  # already a git repo — the workflow uses it
} elseif ($GitInit) {
  & git -C $Target init -q
  & git -C $Target add -A
  & git -C $Target commit -q -m "chore: adopt forge-ai" 2>$null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  + initialized a git repo + baseline commit (chore: adopt forge-ai)"
  } else {
    Write-Host "  + initialized a git repo (baseline commit skipped — set git user.name/email, then commit)"
  }
} else {
  Write-Host "  ! not a git repo — forge-ai's workflow (branches, commits) and the ship gates assume git."
  Write-Host "    Run 'git init' here, or re-run the installer with -GitInit."
}

Write-Host "forge-ai installed."
Write-Host "  next: (1) fill PROJECT.md   (2) in Codex, trust the project when prompted"
Write-Host "        (3) open the project in any of Claude Code / Codex / OpenCode"
Write-Host "  to customize or upgrade: edit the forge-ai source, then re-run this installer"
Write-Host "  against the project (-Upgrade, or a bare re-run from inside it)."
