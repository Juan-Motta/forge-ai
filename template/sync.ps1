#!/usr/bin/env pwsh
#
# forge-ai sync (Windows / PowerShell) — generate each engine's config + skills from the
# neutral source. No symlinks.
#
#   pwsh ./sync.ps1
#
# Single source of truth is the neutral layout at the project root:
#   CLAUDE.md                     -> instructions (also copied to AGENTS.md)
#   skills\<name>\SKILL.md        -> skills, copied into each engine's discovery dir
#   configs\claude\settings.json  -> .claude\settings.json
#   configs\codex\config.toml     -> .codex\config.toml
#   configs\opencode.json         -> opencode.json (OpenCode reads it from the root)
#
# GENERATED (do NOT edit): AGENTS.md, opencode.json, .claude, .codex, .opencode. Edit the
# neutral source above, then re-run this script. Generated paths are gitignored.
#
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path (Join-Path $Root 'skills'))) {
  Write-Error "no skills\ base found in $Root"; exit 2
}

# instructions: CLAUDE.md -> AGENTS.md
$claude = Join-Path $Root 'CLAUDE.md'
if (Test-Path $claude) { Copy-Item $claude (Join-Path $Root 'AGENTS.md') -Force }

# per-engine skills copy (full mirror: replace so deletions propagate)
foreach ($eng in '.claude', '.codex', '.opencode') {
  $engPath = Join-Path $Root $eng
  New-Item -ItemType Directory -Force -Path $engPath | Out-Null
  $skillsPath = Join-Path $engPath 'skills'
  if (Test-Path $skillsPath) { Remove-Item -Recurse -Force $skillsPath }
  Copy-Item -Recurse (Join-Path $Root 'skills') $skillsPath
}

# per-engine config, placed where each engine looks for it
$cClaude = Join-Path $Root 'configs\claude\settings.json'
if (Test-Path $cClaude) { Copy-Item $cClaude (Join-Path $Root '.claude\settings.json') -Force }
$cCodex = Join-Path $Root 'configs\codex\config.toml'
if (Test-Path $cCodex) { Copy-Item $cCodex (Join-Path $Root '.codex\config.toml') -Force }
$cOpen = Join-Path $Root 'configs\opencode.json'
if (Test-Path $cOpen) { Copy-Item $cOpen (Join-Path $Root 'opencode.json') -Force }

Write-Host "forge-ai sync: generated AGENTS.md, opencode.json, and .claude/.codex/.opencode (config + skills) from the neutral source"
