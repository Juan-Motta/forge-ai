#!/usr/bin/env pwsh
#
# forge-ai installer (Windows / PowerShell) — copy the workflow discipline into a target
# project. Mirror of install.sh.
#
#   pwsh ./install.ps1 <target-dir> [-Upgrade]
#
# The shippable payload is the NEUTRAL source in ./src/. Keeping it in a subfolder keeps the
# repo root free of files that would collide when working ON forge-ai. This installer copies
# src/* into the target's root, then runs sync.ps1 to GENERATE each engine's config + skills
# (.claude/ + .agents/skills + .codex/config.toml + AGENTS.md + opencode.json). No symlinks
# (Windows-safe). Generated engine artifacts are gitignored — regenerate any time with
# ./sync.ps1.
#
param(
  [Parameter(Mandatory = $true)][string]$Target,
  [switch]$Upgrade
)
$ErrorActionPreference = 'Stop'

$Src = Split-Path -Parent $MyInvocation.MyCommand.Path
$Payload = Join-Path $Src 'src'
$Mode = if ($Upgrade) { 'upgrade' } else { 'install' }

if (-not (Test-Path -PathType Container $Target)) { Write-Error "target dir not found: $Target"; exit 2 }
$Target = (Resolve-Path $Target).Path
if ($Target -eq $Src) { Write-Error "refusing to install into forge-ai itself"; exit 2 }
if (-not ((Test-Path (Join-Path $Payload 'CLAUDE.md')) -and (Test-Path (Join-Path $Payload 'skills')))) {
  Write-Error "payload not found — run this from the forge-ai repo root"; exit 2
}

Write-Host "forge-ai -> installing into: $Target  (mode: $Mode)"

function Has-ForgeMarker([string]$file) {
  return (Test-Path $file) -and (Select-String -Quiet -SimpleMatch 'Workflow discipline for Claude Code' $file)
}

# --- MANAGED: CLAUDE.md (back up a pre-existing, non-forge one) ---
$tClaude = Join-Path $Target 'CLAUDE.md'
if ((Test-Path $tClaude) -and -not (Has-ForgeMarker $tClaude)) {
  Copy-Item $tClaude "$tClaude.pre-forge.bak" -Force
  Write-Host "  ! backed up existing CLAUDE.md -> CLAUDE.md.pre-forge.bak (move project-specifics into PROJECT.md)"
}
Copy-Item (Join-Path $Payload 'CLAUDE.md') $tClaude -Force

# --- MANAGED: framework skills/ and shared/rules/ (per-entry overwrite by name) ---
New-Item -ItemType Directory -Force -Path (Join-Path $Target 'skills'), (Join-Path $Target 'shared/rules') | Out-Null
foreach ($d in Get-ChildItem -Directory (Join-Path $Payload 'skills')) {
  $dest = Join-Path $Target "skills/$($d.Name)"
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
  Copy-Item -Recurse $d.FullName $dest
}
foreach ($f in Get-ChildItem -File (Join-Path $Payload 'shared/rules') -Filter *.md) {
  Copy-Item $f.FullName (Join-Path $Target "shared/rules/$($f.Name)") -Force
}

# --- MANAGED: sync scripts (the generator) ---
Copy-Item (Join-Path $Payload 'sync.sh')  (Join-Path $Target 'sync.sh')  -Force
Copy-Item (Join-Path $Payload 'sync.ps1') (Join-Path $Target 'sync.ps1') -Force

# --- MANAGED: templates + framework doc + docs/ scaffolding ---
foreach ($t in 'state.template.md', 'CONTINUITY.template.md', 'PROJECT.template.md') {
  Copy-Item (Join-Path $Payload $t) (Join-Path $Target $t) -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $Target 'docs') | Out-Null
Copy-Item (Join-Path $Payload 'docs/extending.md') (Join-Path $Target 'docs/extending.md') -Force
foreach ($d in 'prds', 'plans', 'research', 'solutions', 'adr') {
  $dd = Join-Path $Target "docs/$d"
  New-Item -ItemType Directory -Force -Path $dd | Out-Null
  $gk = Join-Path $dd '.gitkeep'
  if (-not (Test-Path $gk)) { New-Item -ItemType File -Path $gk | Out-Null }
}

# --- PROJECT-OWNED: PROJECT.md / CONTINUITY.md (create only if missing) ---
$tProject = Join-Path $Target 'PROJECT.md'
if (-not (Test-Path $tProject)) {
  Copy-Item (Join-Path $Payload 'PROJECT.template.md') $tProject
  Write-Host "  + created PROJECT.md (fill in persona/info/variables/special rules)"
}
$tCont = Join-Path $Target 'CONTINUITY.md'
if (-not (Test-Path $tCont)) { Copy-Item (Join-Path $Payload 'CONTINUITY.template.md') $tCont }

# --- PROJECT-OWNED: neutral configs (create if missing; migrate a pre-existing engine
#     config so we don't lose the project's own gate settings) ---
function Seed-Config([string]$cfgRel, [string]$preRel) {
  $cfg = Join-Path $Target $cfgRel
  if (Test-Path $cfg) { return }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cfg) | Out-Null
  $pre = Join-Path $Target $preRel
  if (Test-Path $pre) {
    Copy-Item $pre $cfg
    Write-Host "  + migrated existing $preRel -> $cfgRel (edit configs/ from now on)"
  } else {
    Copy-Item (Join-Path $Payload $cfgRel) $cfg
  }
}
Seed-Config 'configs/claude/settings.json' '.claude/settings.json'
Seed-Config 'configs/codex/config.toml'    '.codex/config.toml'
Seed-Config 'configs/opencode.json'        'opencode.json'

# --- back up any pre-existing, NON-forge per-engine skills dir before sync overwrites it ---
foreach ($eng in '.claude', '.agents') {
  $sd = Join-Path $Target "$eng/skills"
  if ((Test-Path $sd) -and -not (Test-Path (Join-Path $sd 'new-feature/SKILL.md'))) {
    Move-Item $sd "$sd.pre-forge.bak"
    Write-Host "  ! backed up existing $eng/skills -> $eng/skills.pre-forge.bak (put custom skills in ./skills)"
  }
}
# back up a real, non-forge AGENTS.md before sync overwrites it
$tAgents = Join-Path $Target 'AGENTS.md'
if ((Test-Path $tAgents) -and -not (Has-ForgeMarker $tAgents)) {
  Copy-Item $tAgents "$tAgents.pre-forge.bak" -Force
  Write-Host "  ! backed up existing AGENTS.md -> AGENTS.md.pre-forge.bak"
}

# --- GENERATE engine dirs + AGENTS.md + opencode.json via sync (no symlinks) ---
& (Join-Path $Target 'sync.ps1') | Out-Null

# --- .gitignore (merge, don't clobber): generated engine artifacts + local state ---
$gi = Join-Path $Target '.gitignore'
if (-not (Test-Path $gi)) { New-Item -ItemType File -Path $gi | Out-Null }
$marker = '# forge-ai (generated — regenerate with ./sync.sh)'
if (-not (Select-String -Quiet -SimpleMatch $marker $gi)) {
  $block = @"

# forge-ai (generated — regenerate with ./sync.sh)
.claude/
.agents/
.codex/
/AGENTS.md
/opencode.json

# forge-ai (local state)
.DS_Store
.workflow/
"@
  Add-Content -Path $gi -Value $block
}

# --- warn if a project-owned config lacks the forge push/PR gate ---
function Warn-Gate([string]$rel, [string]$needle, [string]$hint) {
  $f = Join-Path $Target $rel
  if ((Test-Path $f) -and -not (Select-String -Quiet -SimpleMatch $needle $f)) {
    Write-Host "  ! $rel has no forge push/PR gate ($hint) — add it, then re-run ./sync.ps1."
  }
}
Warn-Gate 'configs/claude/settings.json' 'git push'       'ask-tier on git push / gh pr create'
Warn-Gate 'configs/codex/config.toml'    'approval_policy' 'approval_policy'
Warn-Gate 'configs/opencode.json'        'git push'       'permission.bash git push* / gh pr create*'

# --- post-install validation: generated skill copies + AGENTS.md must exist ---
$ok = $true
foreach ($p in '.claude/skills', '.agents/skills') {
  if (-not (Test-Path (Join-Path $Target "$p/new-feature/SKILL.md"))) {
    Write-Host "  ! discovery FAILED: $p was not generated"; $ok = $false
  }
}
if (-not (Test-Path $tAgents)) { Write-Host "  ! AGENTS.md was not generated"; $ok = $false }
if ($ok) {
  Write-Host "  + validation: skill-discovery paths (.claude + .agents) + AGENTS.md generated"
} else {
  Write-Host "  x validation found issues above — fix before relying on forge-ai here"
}

Write-Host "forge-ai installed."
Write-Host "  next: (1) fill PROJECT.md   (2) in Codex, trust the project when prompted"
Write-Host "        (3) open the project in any of Claude Code / Codex / OpenCode"
Write-Host "  edit the neutral source (skills/, configs/, CLAUDE.md), then re-run ./sync.ps1"
Write-Host "  to regenerate. Generated engine dirs are gitignored."
